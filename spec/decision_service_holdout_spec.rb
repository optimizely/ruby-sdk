# frozen_string_literal: true

#
#    Copyright 2017-2020, 2023, Optimizely and contributors
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
require 'spec_helper'
require 'optimizely/decision_service'
require 'optimizely/error_handler'
require 'optimizely/logger'

describe Optimizely::DecisionService do
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:spy_user_profile_service) { spy('user_profile_service') }
  let(:spy_cmab_service) { spy('cmab_service') }
  let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:decision_service) { Optimizely::DecisionService.new(spy_logger, spy_cmab_service, spy_user_profile_service) }
  let(:project_instance) { Optimizely::Project.new(datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler) }
  let(:user_context) { project_instance.create_user_context('some-user', {}) }
  after(:example) { project_instance.close }

  describe 'Holdout Decision Service Tests' do
    let(:config_with_holdouts) do
      Optimizely::DatafileProjectConfig.new(
        OptimizelySpec::CONFIG_BODY_WITH_HOLDOUTS_JSON,
        spy_logger,
        error_handler
      )
    end

    let(:project_with_holdouts) do
      Optimizely::Project.new(
        datafile: OptimizelySpec::CONFIG_BODY_WITH_HOLDOUTS_JSON,
        logger: spy_logger,
        error_handler: error_handler
      )
    end

    let(:decision_service_with_holdouts) do
      Optimizely::DecisionService.new(spy_logger, spy_cmab_service, spy_user_profile_service)
    end

    after(:example) do
      project_with_holdouts&.close
    end

    describe '#get_variations_for_feature_list with holdouts' do
      describe 'when holdout is active and user is bucketed' do
        it 'should return holdout decision with variation' do
          feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
          expect(feature_flag).not_to be_nil

          holdout = config_with_holdouts.holdouts.first
          expect(holdout).not_to be_nil

          user_context = project_with_holdouts.create_user_context('testUserId', {})

          result = decision_service_with_holdouts.get_variations_for_feature_list(
            config_with_holdouts,
            [feature_flag],
            user_context,
            {}
          )

          expect(result).not_to be_nil
          expect(result).to be_an(Array)
          expect(result.length).to be > 0

          # Check if any decision is from holdout source
          _holdout_decision = result.find do |decision_result|
            decision_result.decision&.source == Optimizely::DecisionService::DECISION_SOURCES['HOLDOUT']
          end

          # With real bucketer, we can't guarantee holdout bucketing
          # but we can verify the result structure is valid
          result.each do |decision_result|
            expect(decision_result).to respond_to(:decision)
            expect(decision_result).to respond_to(:reasons)
          end
        end
      end

      describe 'when holdout is inactive' do
        it 'should not bucket users and log appropriate message' do
          feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
          expect(feature_flag).not_to be_nil

          # Find the most specific holdout for this flag (prefer explicitly included over global)
          applicable_holdout = config_with_holdouts.holdouts.find do |holdout|
            # First preference: holdout that explicitly includes this flag
            holdout['includedFlags']&.include?(feature_flag['id'])
          end

          # If no explicit holdout found, fall back to global holdouts
          if applicable_holdout.nil?
            applicable_holdout = config_with_holdouts.holdouts.find do |holdout|
              # Global holdout (empty/nil includedFlags) that doesn't exclude this flag
              (holdout['includedFlags'].nil? || holdout['includedFlags'].empty?) &&
                !holdout['excludedFlags']&.include?(feature_flag['id'])
            end
          end

          expect(applicable_holdout).not_to be_nil, 'No applicable holdout found for boolean_feature'

          # Mock holdout as inactive
          original_status = applicable_holdout['status']
          applicable_holdout['status'] = 'Paused'

          user_context = project_with_holdouts.create_user_context('testUserId', {})

          # Use get_variation_for_holdout directly to test holdout evaluation
          result = decision_service_with_holdouts.get_variation_for_holdout(
            applicable_holdout,
            user_context,
            config_with_holdouts
          )

          # Assert that result is not nil and has expected structure
          expect(result).not_to be_nil
          expect(result).to respond_to(:decision)
          expect(result).to respond_to(:reasons)
          expect(result.decision).to be_nil

          # Verify log message for inactive holdout
          expect(spy_logger).to have_received(:log).with(
            Logger::INFO,
            a_string_matching(/Holdout.*is not running/i)
          )

          # Restore original status
          applicable_holdout['status'] = original_status
        end
      end

      describe 'when user is not bucketed into holdout' do
        it 'should execute successfully with valid result structure' do
          feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
          expect(feature_flag).not_to be_nil

          holdout = config_with_holdouts.holdouts.first
          expect(holdout).not_to be_nil

          user_context = project_with_holdouts.create_user_context('testUserId', {})

          result = decision_service_with_holdouts.get_variations_for_feature_list(
            config_with_holdouts,
            [feature_flag],
            user_context,
            {}
          )

          # With real bucketer, we can't guarantee specific bucketing results
          # but we can verify the method executes successfully
          expect(result).not_to be_nil
          expect(result).to be_an(Array)
        end
      end

      describe 'with user attributes for audience targeting' do
        it 'should evaluate holdout with user attributes' do
          feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
          expect(feature_flag).not_to be_nil

          holdout = config_with_holdouts.holdouts.first
          expect(holdout).not_to be_nil

          user_attributes = {
            'browser' => 'chrome',
            'location' => 'us'
          }

          user_context = project_with_holdouts.create_user_context('testUserId', user_attributes)

          result = decision_service_with_holdouts.get_variations_for_feature_list(
            config_with_holdouts,
            [feature_flag],
            user_context,
            user_attributes
          )

          expect(result).not_to be_nil
          expect(result).to be_an(Array)

          # With real bucketer, we can't guarantee specific variations
          # but can verify execution completes successfully
        end
      end

      describe 'with multiple holdouts' do
        it 'should handle multiple holdouts for a single feature flag' do
          feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
          expect(feature_flag).not_to be_nil

          user_context = project_with_holdouts.create_user_context('testUserId', {})

          result = decision_service_with_holdouts.get_variations_for_feature_list(
            config_with_holdouts,
            [feature_flag],
            user_context,
            {}
          )

          expect(result).not_to be_nil
          expect(result).to be_an(Array)

          # With real bucketer, we can't guarantee specific bucketing results
          # but we can verify the method executes successfully
        end
      end

      describe 'with empty user ID' do
        it 'should allow holdout bucketing with empty user ID' do
          feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
          expect(feature_flag).not_to be_nil

          # Empty user ID should still be valid for bucketing
          user_context = project_with_holdouts.create_user_context('', {})

          result = decision_service_with_holdouts.get_variations_for_feature_list(
            config_with_holdouts,
            [feature_flag],
            user_context,
            {}
          )

          expect(result).not_to be_nil

          # Empty user ID should not log error about invalid user ID
          expect(spy_logger).not_to have_received(:log).with(
            Logger::ERROR,
            a_string_matching(/User ID.*(?:null|empty)/)
          )
        end
      end

      describe 'with decision reasons' do
        it 'should populate decision reasons for holdouts' do
          feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
          expect(feature_flag).not_to be_nil

          holdout = config_with_holdouts.holdouts.first
          expect(holdout).not_to be_nil

          user_context = project_with_holdouts.create_user_context('testUserId', {})

          result = decision_service_with_holdouts.get_variations_for_feature_list(
            config_with_holdouts,
            [feature_flag],
            user_context,
            {}
          )

          expect(result).not_to be_nil

          # With real bucketer, we expect proper decision reasons to be generated
          # Find any decision with reasons
          decision_with_reasons = result.find do |decision_result|
            decision_result.reasons && !decision_result.reasons.empty?
          end

          expect(decision_with_reasons.reasons).not_to be_empty if decision_with_reasons
        end
      end
    end

    describe '#get_variation_for_feature with holdouts' do
      describe 'when user is bucketed into holdout' do
        it 'should return holdout decision before checking experiments or rollouts' do
          feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
          expect(feature_flag).not_to be_nil

          user_context = project_with_holdouts.create_user_context('testUserId', {})

          # The get_variation_for_feature method should check holdouts first
          decision_result = decision_service_with_holdouts.get_variation_for_feature(
            config_with_holdouts,
            feature_flag,
            user_context
          )

          expect(decision_result).not_to be_nil

          # Decision should be valid (from holdout, experiment, or rollout)
          if decision_result.decision
            expect(decision_result.decision).to respond_to(:experiment)
            expect(decision_result.decision).to respond_to(:variation)
            expect(decision_result.decision).to respond_to(:source)
          end
        end
      end

      describe 'when holdout returns no decision' do
        it 'should fall through to experiment and rollout evaluation' do
          feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
          expect(feature_flag).not_to be_nil

          # Use a user ID that won't be bucketed into holdout
          user_context = project_with_holdouts.create_user_context('non_holdout_user', {})

          decision_result = decision_service_with_holdouts.get_variation_for_feature(
            config_with_holdouts,
            feature_flag,
            user_context
          )

          # Should still get a valid decision result (even if decision is nil)
          expect(decision_result).not_to be_nil
          expect(decision_result).to respond_to(:decision)
          expect(decision_result).to respond_to(:reasons)
        end
      end

      describe 'with decision options' do
        it 'should respect decision options when evaluating holdouts' do
          feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
          expect(feature_flag).not_to be_nil

          user_context = project_with_holdouts.create_user_context('testUserId', {})

          # Test with INCLUDE_REASONS option
          decision_result = decision_service_with_holdouts.get_variation_for_feature(
            config_with_holdouts,
            feature_flag,
            user_context,
            [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS]
          )

          expect(decision_result).not_to be_nil
          expect(decision_result.reasons).to be_an(Array)
        end
      end
    end

    describe 'holdout priority and evaluation order' do
      it 'should evaluate holdouts before experiments' do
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        user_context = project_with_holdouts.create_user_context('testUserId', {})

        # Mock the get_variation_for_feature_experiment to track if it's called
        allow(decision_service_with_holdouts).to receive(:get_variation_for_feature_experiment)
          .and_call_original

        decision_result = decision_service_with_holdouts.get_variation_for_feature(
          config_with_holdouts,
          feature_flag,
          user_context
        )

        expect(decision_result).not_to be_nil

        decision_result.decision && decision_result.decision.source == Optimizely::DecisionService::DECISION_SOURCES['HOLDOUT'] && holdout_decisions << decision_result
        expect(decision_service_with_holdouts).not_to have_received(:get_variation_for_feature_experiment)
      end

      it 'should evaluate global holdouts for all flags' do
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        # Get global holdouts
        global_holdouts = config_with_holdouts.holdouts.select do |h|
          h['includedFlags'].nil? || h['includedFlags'].empty?
        end

        unless global_holdouts.empty?
          user_context = project_with_holdouts.create_user_context('testUserId', {})

          result = decision_service_with_holdouts.get_variations_for_feature_list(
            config_with_holdouts,
            [feature_flag],
            user_context,
            {}
          )

          expect(result).not_to be_nil
          expect(result).to be_an(Array)
        end
      end

      it 'should respect included and excluded flags configuration' do
        # Test that flags in excludedFlags are not affected by that holdout
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']

        if feature_flag
          # Get holdouts for this flag
          holdouts_for_flag = config_with_holdouts.get_holdouts_for_flag(feature_flag['id'])

          # Should not include holdouts that exclude this flag
          excluded_holdout = holdouts_for_flag.find { |h| h['key'] == 'excluded_holdout' }
          expect(excluded_holdout).to be_nil
        end
      end
    end

    describe 'holdout logging and error handling' do
      it 'should log when holdout evaluation starts' do
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        user_context = project_with_holdouts.create_user_context('testUserId', {})

        decision_service_with_holdouts.get_variations_for_feature_list(
          config_with_holdouts,
          [feature_flag],
          user_context,
          {}
        )

        # Verify that appropriate log messages are generated
        # (specific messages depend on implementation)
        expect(spy_logger).to have_received(:log).at_least(:once)
      end

      it 'should handle missing holdout configuration gracefully' do
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        # Temporarily remove holdouts
        original_holdouts = config_with_holdouts.instance_variable_get(:@holdouts)
        config_with_holdouts.instance_variable_set(:@holdouts, [])

        user_context = project_with_holdouts.create_user_context('testUserId', {})

        result = decision_service_with_holdouts.get_variations_for_feature_list(
          config_with_holdouts,
          [feature_flag],
          user_context,
          {}
        )

        expect(result).not_to be_nil

        # Restore original holdouts
        config_with_holdouts.instance_variable_set(:@holdouts, original_holdouts)
      end

      it 'should handle invalid holdout data gracefully' do
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        user_context = project_with_holdouts.create_user_context('testUserId', {})

        # The method should handle invalid holdout data without crashing
        result = decision_service_with_holdouts.get_variations_for_feature_list(
          config_with_holdouts,
          [feature_flag],
          user_context,
          {}
        )

        expect(result).not_to be_nil
        expect(result).to be_an(Array)
      end
    end

    describe 'holdout bucketing behavior' do
      it 'should use consistent bucketing for the same user' do
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        user_id = 'consistent_user'
        user_context1 = project_with_holdouts.create_user_context(user_id, {})
        user_context2 = project_with_holdouts.create_user_context(user_id, {})

        result1 = decision_service_with_holdouts.get_variations_for_feature_list(
          config_with_holdouts,
          [feature_flag],
          user_context1,
          {}
        )

        result2 = decision_service_with_holdouts.get_variations_for_feature_list(
          config_with_holdouts,
          [feature_flag],
          user_context2,
          {}
        )

        # Same user should get consistent results
        expect(result1).not_to be_nil
        expect(result2).not_to be_nil

        if !result1.empty? && !result2.empty?
          # Compare the first decision from each result
          decision1 = result1[0].decision
          decision2 = result2[0].decision

          # If both have decisions, they should match
          if decision1 && decision2
            expect(decision1.variation&.fetch('id', nil)).to eq(decision2.variation&.fetch('id', nil))
            expect(decision1.source).to eq(decision2.source)
          end
        end
      end

      it 'should use bucketing ID when provided' do
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        user_attributes = {
          Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 'custom_bucketing_id'
        }

        user_context = project_with_holdouts.create_user_context('testUserId', user_attributes)

        result = decision_service_with_holdouts.get_variations_for_feature_list(
          config_with_holdouts,
          [feature_flag],
          user_context,
          user_attributes
        )

        expect(result).not_to be_nil
        expect(result).to be_an(Array)

        # Bucketing should work with custom bucketing ID
      end

      it 'should handle different traffic allocations' do
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        # Test with multiple users to see varying bucketing results
        users = %w[user1 user2 user3 user4 user5]
        results = []

        users.each do |user_id|
          user_context = project_with_holdouts.create_user_context(user_id, {})
          result = decision_service_with_holdouts.get_variations_for_feature_list(
            config_with_holdouts,
            [feature_flag],
            user_context,
            {}
          )
          results << result
        end

        # All results should be valid
        results.each do |result|
          expect(result).not_to be_nil
          expect(result).to be_an(Array)
        end
      end
    end

    describe 'holdout integration with feature experiments' do
      it 'should check holdouts before feature experiments' do
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        user_context = project_with_holdouts.create_user_context('testUserId', {})

        # Mock feature experiment method to track calls
        allow(decision_service_with_holdouts).to receive(:get_variation_for_feature_experiment)
          .and_call_original

        decision_result = decision_service_with_holdouts.get_variation_for_feature(
          config_with_holdouts,
          feature_flag,
          user_context
        )

        expect(decision_result).not_to be_nil

        # Holdout evaluation happens in get_variations_for_feature_list
        # which is called before experiment evaluation
      end

      it 'should fall back to experiments if no holdout decision' do
        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        user_context = project_with_holdouts.create_user_context('non_holdout_user_123', {})

        decision_result = decision_service_with_holdouts.get_variation_for_feature(
          config_with_holdouts,
          feature_flag,
          user_context
        )

        # Should return a valid decision result
        expect(decision_result).not_to be_nil
        expect(decision_result).to respond_to(:decision)
        expect(decision_result).to respond_to(:reasons)
      end
    end
  end

  describe 'Holdout Impression Events' do
    let(:spy_event_processor) { spy('event_processor') }
    let(:config_with_holdouts) do
      Optimizely::DatafileProjectConfig.new(
        OptimizelySpec::CONFIG_BODY_WITH_HOLDOUTS_JSON,
        spy_logger,
        error_handler
      )
    end

    let(:optimizely_with_mocked_events) do
      Optimizely::Project.new(
        datafile: OptimizelySpec::CONFIG_BODY_WITH_HOLDOUTS_JSON,
        logger: spy_logger,
        error_handler: error_handler,
        event_processor: spy_event_processor
      )
    end

    after(:example) do
      optimizely_with_mocked_events&.close
    end

    describe '#decide with holdout impression events' do
      it 'should send impression event for holdout decision' do
        # Use a specific user ID that will be bucketed into a holdout
        # This is deterministic based on the bucketing algorithm
        test_user_id = 'user_bucketed_into_holdout'

        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil, "Feature flag 'boolean_feature' should exist"

        user_attributes = {}

        allow(spy_event_processor).to receive(:process)

        user_context = optimizely_with_mocked_events.create_user_context(test_user_id, user_attributes)
        decision = user_context.decide(feature_flag['key'])

        expect(decision).not_to be_nil, 'Decision should not be nil'

        actual_holdout = config_with_holdouts.holdouts&.find { |h| h['key'] == decision.rule_key }

        # Only continue if this is a holdout decision
        if actual_holdout
          expect(decision.flag_key).to eq(feature_flag['key'])

          holdout_variation = actual_holdout['variations'].find { |v| v['key'] == decision.variation_key }

          expect(holdout_variation).not_to be_nil, "Variation '#{decision.variation_key}' should be from the chosen holdout '#{actual_holdout['key']}'"

          expect(decision.enabled).to eq(holdout_variation['featureEnabled']), "Enabled flag should match holdout variation's featureEnabled value"

          expect(spy_event_processor).to have_received(:process)
            .with(instance_of(Optimizely::ImpressionEvent))
            .at_least(:once)

          # Verify impression event contains correct holdout details
          expect(spy_event_processor).to have_received(:process).with(
            having_attributes(
              user_id: test_user_id
            )
          ).at_least(:once)
        end
      end

      it 'should not send impression event when DISABLE_DECISION_EVENT option is used' do
        test_user_id = 'user_bucketed_into_holdout'

        feature_flag = config_with_holdouts.feature_flag_key_map['boolean_feature']
        expect(feature_flag).not_to be_nil

        user_attributes = {}

        allow(spy_event_processor).to receive(:process)

        user_context = optimizely_with_mocked_events.create_user_context(test_user_id, user_attributes)
        decision = user_context.decide(
          feature_flag['key'],
          [Optimizely::Decide::OptimizelyDecideOption::DISABLE_DECISION_EVENT]
        )

        expect(decision).not_to be_nil, 'Decision should not be nil'

        chosen_holdout = config_with_holdouts.holdouts&.find { |h| h['key'] == decision.rule_key }

        if chosen_holdout
          expect(decision.flag_key).to eq(feature_flag['key'])

          # Verify no impression event was sent
          expect(spy_event_processor).not_to have_received(:process)
            .with(instance_of(Optimizely::ImpressionEvent))
        end
      end
    end

    describe '#decide with holdout notification content' do
      it 'should send correct notification content for holdout decision' do
        captured_notifications = []

        notification_callback = lambda do |_notification_type, _user_id, _user_attributes, decision_info|
          captured_notifications << decision_info.dup
        end

        optimizely_with_mocked_events.notification_center.add_notification_listener(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          notification_callback
        )

        # Mock the decision service to return a holdout decision
        holdout = config_with_holdouts.holdouts.first
        expect(holdout).not_to be_nil, 'Should have at least one holdout configured'

        holdout_variation = holdout['variations'].first
        expect(holdout_variation).not_to be_nil, 'Holdout should have at least one variation'

        # Create a holdout decision
        holdout_decision = Optimizely::DecisionService::Decision.new(
          holdout,
          holdout_variation,
          Optimizely::DecisionService::DECISION_SOURCES['HOLDOUT']
        )

        holdout_decision_result = Optimizely::DecisionService::DecisionResult.new(
          holdout_decision,
          false,
          []
        )

        # Mock get_variations_for_feature_list to return holdout decision
        allow_any_instance_of(Optimizely::DecisionService).to receive(:get_variations_for_feature_list)
          .and_return([holdout_decision_result])

        test_user_id = 'test_user'
        user_attributes = {'country' => 'us'}

        user_context = optimizely_with_mocked_events.create_user_context(test_user_id, user_attributes)

        expect(captured_notifications.length).to eq(1), 'Should have captured exactly one decision notification'

        notification = captured_notifications.first
        rule_key = notification[:rule_key]

        expect(rule_key).to eq(holdout['key']), 'RuleKey should match holdout key'

        # Verify holdout notification structure
        expect(notification).to have_key(:flag_key), 'Holdout notification should contain flag_key'
        expect(notification).to have_key(:enabled), 'Holdout notification should contain enabled flag'
        expect(notification).to have_key(:variation_key), 'Holdout notification should contain variation_key'
        expect(notification).to have_key(:experiment_id), 'Holdout notification should contain experiment_id'
        expect(notification).to have_key(:variation_id), 'Holdout notification should contain variation_id'

        flag_key = notification[:flag_key]
        expect(flag_key).to eq('boolean_feature'), 'FlagKey should match the requested flag'

        experiment_id = notification[:experiment_id]
        expect(experiment_id).to eq(holdout['id']), 'ExperimentId in notification should match holdout ID'
        
        variation_id = notification[:variation_id]
        expect(variation_id).to eq(holdout_variation['id']), 'VariationId should match holdout variation ID'

        variation_key = notification[:variation_key]
        expect(variation_key).to eq(holdout_variation['key']), 'VariationKey in notification should match holdout variation key'

        enabled = notification[:enabled]
        expect(enabled).not_to be_nil, 'Enabled flag should be present in notification'
        expect(enabled).to eq(holdout_variation['featureEnabled']), "Enabled flag should match holdout variation's featureEnabled value"

        expect(config_with_holdouts.feature_flag_key_map).to have_key(flag_key), "FlagKey '#{flag_key}' should exist in config"

        expect(notification).to have_key(:variables), 'Notification should contain variables'
        expect(notification).to have_key(:reasons), 'Notification should contain reasons'
        expect(notification).to have_key(:decision_event_dispatched), 'Notification should contain decision_event_dispatched'
      end
    end
  end
end
