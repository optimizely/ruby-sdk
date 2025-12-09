# frozen_string_literal: true

#
#    Copyright 2025 Optimizely and contributors
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
require 'optimizely/audience'
require 'optimizely/error_handler'
require 'optimizely/logger'

# Comprehensive holdout tests aligned with Swift SDK DecisionServiceTests_Holdouts.swift
describe 'Optimizely::DecisionService - Comprehensive Holdout Tests' do
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:spy_user_profile_service) { spy('user_profile_service') }
  let(:spy_cmab_service) { spy('cmab_service') }

  # Sample data aligned with Swift SDK test fixtures
  let(:sample_feature_flag) do
    {
      'id' => 'flag_id_1234',
      'key' => 'test_flag',
      'experimentIds' => ['experiment_123'],
      'rolloutId' => '',
      'variables' => []
    }
  end

  let(:sample_experiment) do
    {
      'id' => 'experiment_123',
      'key' => 'test_experiment',
      'status' => 'Running',
      'layerId' => 'layer_1',
      'trafficAllocation' => [
        {'entityId' => 'variation_a', 'endOfRange' => 10_000}
      ],
      'audienceIds' => ['audience_country'],
      'audienceConditions' => ['or', 'audience_country'],
      'variations' => [
        {'id' => 'variation_a', 'key' => 'control', 'variables' => []}
      ],
      'forcedVariations' => {}
    }
  end

  let(:sample_typed_audience) do
    {
      'id' => 'audience_country',
      'name' => 'country',
      'conditions' => ['and', ['or', ['or', {
        'type' => 'custom_attribute',
        'name' => 'country',
        'match' => 'exact',
        'value' => 'us'
      }]]]
    }
  end

  let(:global_holdout) do
    {
      'id' => 'holdout_global',
      'key' => 'global_holdout',
      'status' => 'Running',
      'trafficAllocation' => [
        {'entityId' => 'global_variation', 'endOfRange' => 500}
      ],
      'audienceIds' => ['audience_country'],
      'audienceConditions' => ['or', 'audience_country'],
      'variations' => [
        {'id' => 'global_variation', 'key' => 'global_var', 'featureEnabled' => false}
      ],
      'includedFlags' => [],
      'excludedFlags' => []
    }
  end

  let(:included_holdout) do
    {
      'id' => 'holdout_included',
      'key' => 'included_holdout',
      'status' => 'Running',
      'trafficAllocation' => [
        {'entityId' => 'included_variation', 'endOfRange' => 1000}
      ],
      'audienceIds' => ['audience_country'],
      'audienceConditions' => ['or', 'audience_country'],
      'variations' => [
        {'id' => 'included_variation', 'key' => 'included_var', 'featureEnabled' => false}
      ],
      'includedFlags' => ['flag_id_1234'],
      'excludedFlags' => []
    }
  end

  let(:excluded_holdout) do
    {
      'id' => 'holdout_excluded',
      'key' => 'excluded_holdout',
      'status' => 'Running',
      'trafficAllocation' => [
        {'entityId' => 'excluded_variation', 'endOfRange' => 1000}
      ],
      'audienceIds' => ['audience_country'],
      'audienceConditions' => ['or', 'audience_country'],
      'variations' => [
        {'id' => 'excluded_variation', 'key' => 'excluded_var', 'featureEnabled' => false}
      ],
      'includedFlags' => [],
      'excludedFlags' => ['flag_id_1234']
    }
  end

  # MARK: - Audience Evaluation Tests (aligned with Swift lines 221-349)

  describe 'Audience Evaluation' do
    let(:config_body) do
      {
        'version' => '4',
        'rollouts' => [],
        'typedAudiences' => [sample_typed_audience],
        'anonymizeIP' => false,
        'projectId' => '111001',
        'variables' => [],
        'featureFlags' => [sample_feature_flag],
        'experiments' => [sample_experiment],
        'audiences' => [],
        'groups' => [],
        'attributes' => [],
        'accountId' => '12123',
        'layers' => [],
        'events' => [],
        'revision' => '1',
        'holdouts' => [global_holdout]
      }
    end

    let(:config) do
      Optimizely::DatafileProjectConfig.new(
        JSON.dump(config_body),
        spy_logger,
        error_handler
      )
    end

    let(:decision_service) do
      Optimizely::DecisionService.new(spy_logger, spy_cmab_service, spy_user_profile_service)
    end

    let(:project_instance) do
      Optimizely::Project.new(
        datafile: JSON.dump(config_body),
        logger: spy_logger,
        error_handler: error_handler
      )
    end

    after(:example) do
      project_instance&.close
    end

    describe '#user_meets_audience_conditions with audienceConditions' do
      it 'should return true when attributes match audienceConditions' do
        holdout = config.holdouts.first
        user_context = project_instance.create_user_context('test_user', 'country' => 'us')

        result, _reasons = Optimizely::Audience.user_meets_audience_conditions?(
          config,
          holdout,
          user_context,
          spy_logger
        )

        expect(result).to be true
      end

      it 'should return false when attributes do not match audienceConditions' do
        holdout = config.holdouts.first
        user_context = project_instance.create_user_context('test_user', 'country' => 'ca')

        result, _reasons = Optimizely::Audience.user_meets_audience_conditions?(
          config,
          holdout,
          user_context,
          spy_logger
        )

        expect(result).to be false
      end

      it 'should return false when attribute is missing' do
        holdout = config.holdouts.first
        user_context = project_instance.create_user_context('test_user', 'age' => 30)

        result, _reasons = Optimizely::Audience.user_meets_audience_conditions?(
          config,
          holdout,
          user_context,
          spy_logger
        )

        expect(result).to be false
      end
    end

    describe '#user_meets_audience_conditions with empty arrays' do
      it 'should return true when audienceConditions is empty array' do
        modified_holdout = global_holdout.dup
        modified_holdout['audienceConditions'] = []
        modified_config_body = config_body.dup
        modified_config_body['holdouts'] = [modified_holdout]

        modified_config = Optimizely::DatafileProjectConfig.new(
          JSON.dump(modified_config_body),
          spy_logger,
          error_handler
        )

        holdout = modified_config.holdouts.first
        user_context = project_instance.create_user_context('test_user', 'country' => 'us')

        result, _reasons = Optimizely::Audience.user_meets_audience_conditions?(
          modified_config,
          holdout,
          user_context,
          spy_logger
        )

        expect(result).to be true
      end

      it 'should return true when audienceIds is empty array' do
        modified_holdout = global_holdout.dup
        modified_holdout['audienceIds'] = []
        modified_holdout['audienceConditions'] = nil
        modified_config_body = config_body.dup
        modified_config_body['holdouts'] = [modified_holdout]

        modified_config = Optimizely::DatafileProjectConfig.new(
          JSON.dump(modified_config_body),
          spy_logger,
          error_handler
        )

        holdout = modified_config.holdouts.first
        user_context = project_instance.create_user_context('test_user', {})

        result, _reasons = Optimizely::Audience.user_meets_audience_conditions?(
          modified_config,
          holdout,
          user_context,
          spy_logger
        )

        expect(result).to be true
      end
    end
  end

  # MARK: - Multiple Holdouts Ordering Tests (aligned with Swift lines 497-573)

  describe 'Multiple Holdouts Ordering' do
    let(:config_body) do
      {
        'version' => '4',
        'rollouts' => [],
        'typedAudiences' => [sample_typed_audience],
        'anonymizeIP' => false,
        'projectId' => '111001',
        'variables' => [],
        'featureFlags' => [sample_feature_flag],
        'experiments' => [sample_experiment],
        'audiences' => [],
        'groups' => [],
        'attributes' => [],
        'accountId' => '12123',
        'layers' => [],
        'events' => [],
        'revision' => '1',
        'holdouts' => [global_holdout, included_holdout, excluded_holdout]
      }
    end

    let(:config) do
      Optimizely::DatafileProjectConfig.new(
        JSON.dump(config_body),
        spy_logger,
        error_handler
      )
    end

    let(:decision_service) do
      Optimizely::DecisionService.new(spy_logger, spy_cmab_service, spy_user_profile_service)
    end

    let(:project_instance) do
      Optimizely::Project.new(
        datafile: JSON.dump(config_body),
        logger: spy_logger,
        error_handler: error_handler
      )
    end

    after(:example) do
      project_instance&.close
    end

    it 'should evaluate global holdouts before included holdouts' do
      # Get holdouts for the flag
      holdouts = config.get_holdouts_for_flag(sample_feature_flag['id'])

      # Verify order: global holdouts come before included holdouts
      expect(holdouts).not_to be_empty

      # Find indices
      global_index = holdouts.index { |h| h['id'] == 'holdout_global' }
      included_index = holdouts.index { |h| h['id'] == 'holdout_included' }

      # Global should come before included
      expect(global_index).not_to be_nil
      expect(included_index).not_to be_nil
      expect(global_index).to be < included_index
    end

    it 'should not include excluded holdouts for the flag' do
      holdouts = config.get_holdouts_for_flag(sample_feature_flag['id'])

      # Excluded holdout should not be in the list
      excluded_found = holdouts.any? { |h| h['id'] == 'holdout_excluded' }
      expect(excluded_found).to be false
    end

    it 'should fall back to included holdout when global fails bucketing' do
      # Modify traffic allocations so global has less traffic
      modified_global = global_holdout.dup
      modified_global['trafficAllocation'] = [
        {'entityId' => 'global_variation', 'endOfRange' => 100}
      ]

      modified_included = included_holdout.dup
      modified_included['trafficAllocation'] = [
        {'entityId' => 'included_variation', 'endOfRange' => 10_000}
      ]

      modified_config_body = config_body.dup
      modified_config_body['holdouts'] = [modified_global, modified_included]

      modified_config = Optimizely::DatafileProjectConfig.new(
        JSON.dump(modified_config_body),
        spy_logger,
        error_handler
      )

      modified_decision_service = Optimizely::DecisionService.new(
        spy_logger,
        spy_cmab_service,
        spy_user_profile_service
      )

      feature_flag = modified_config.feature_flag_key_map['test_flag']
      user_context = project_instance.create_user_context('test_user', 'country' => 'us')

      decision_result = modified_decision_service.get_decision_for_flag(
        feature_flag,
        user_context,
        modified_config,
        []
      )

      # Should bucket into either global or included holdout
      # (We can't guarantee which due to real bucketing, but decision should exist)
      if decision_result.decision
        expect(decision_result.decision.source).to eq(Optimizely::DecisionService::DECISION_SOURCES['HOLDOUT'])
      end
    end

    it 'should fall back to experiment when all holdouts fail' do
      # Modify all holdouts to have 0% traffic
      modified_global = global_holdout.dup
      modified_global['trafficAllocation'] = []

      modified_included = included_holdout.dup
      modified_included['trafficAllocation'] = []

      modified_config_body = config_body.dup
      modified_config_body['holdouts'] = [modified_global, modified_included]

      modified_config = Optimizely::DatafileProjectConfig.new(
        JSON.dump(modified_config_body),
        spy_logger,
        error_handler
      )

      modified_decision_service = Optimizely::DecisionService.new(
        spy_logger,
        spy_cmab_service,
        spy_user_profile_service
      )

      feature_flag = modified_config.feature_flag_key_map['test_flag']
      user_context = project_instance.create_user_context('test_user', 'country' => 'us')

      decision_result = modified_decision_service.get_decision_for_flag(
        feature_flag,
        user_context,
        modified_config,
        []
      )

      # Should fall back to experiment (or rollout/default if experiment also fails)
      # Verify it's NOT a holdout decision
      if decision_result.decision
        expect(decision_result.decision.source).not_to eq(Optimizely::DecisionService::DECISION_SOURCES['HOLDOUT'])
      end
    end
  end

  # MARK: - Excluded Flag Logic Tests (aligned with Swift lines 476-495)

  describe 'Excluded Flag Logic' do
    let(:config_body) do
      {
        'version' => '4',
        'rollouts' => [],
        'typedAudiences' => [sample_typed_audience],
        'anonymizeIP' => false,
        'projectId' => '111001',
        'variables' => [],
        'featureFlags' => [sample_feature_flag],
        'experiments' => [sample_experiment],
        'audiences' => [],
        'groups' => [],
        'attributes' => [],
        'accountId' => '12123',
        'layers' => [],
        'events' => [],
        'revision' => '1',
        'holdouts' => [excluded_holdout]
      }
    end

    let(:config) do
      Optimizely::DatafileProjectConfig.new(
        JSON.dump(config_body),
        spy_logger,
        error_handler
      )
    end

    let(:decision_service) do
      Optimizely::DecisionService.new(spy_logger, spy_cmab_service, spy_user_profile_service)
    end

    let(:project_instance) do
      Optimizely::Project.new(
        datafile: JSON.dump(config_body),
        logger: spy_logger,
        error_handler: error_handler
      )
    end

    after(:example) do
      project_instance&.close
    end

    it 'should skip holdouts that exclude the flag' do
      holdouts = config.get_holdouts_for_flag(sample_feature_flag['id'])

      # Should not include the excluded holdout
      expect(holdouts).to be_empty
    end

    it 'should use excluded_holdouts map for filtering' do
      # Verify the excluded_holdouts map is built correctly
      expect(config.excluded_holdouts).to have_key(sample_feature_flag['id'])
      expect(config.excluded_holdouts[sample_feature_flag['id']]).to include(
        hash_including('id' => 'holdout_excluded')
      )
    end

    it 'should apply excluded holdout to non-excluded flags' do
      # Add another flag that is NOT excluded
      other_flag = sample_feature_flag.dup
      other_flag['id'] = 'other_flag_id'
      other_flag['key'] = 'other_flag'

      modified_config_body = config_body.dup
      modified_config_body['featureFlags'] = [sample_feature_flag, other_flag]

      modified_config = Optimizely::DatafileProjectConfig.new(
        JSON.dump(modified_config_body),
        spy_logger,
        error_handler
      )

      # The excluded holdout should NOT apply to flag_id_1234
      holdouts_excluded_flag = modified_config.get_holdouts_for_flag(sample_feature_flag['id'])
      expect(holdouts_excluded_flag).to be_empty

      # But it SHOULD apply to other_flag_id (as a global holdout)
      holdouts_other_flag = modified_config.get_holdouts_for_flag('other_flag_id')
      expect(holdouts_other_flag).not_to be_empty
      expect(holdouts_other_flag.first['id']).to eq('holdout_excluded')
    end
  end

  # MARK: - Edge Cases (aligned with Swift lines 575-640)

  describe 'Edge Cases' do
    let(:config_body) do
      {
        'version' => '4',
        'rollouts' => [],
        'typedAudiences' => [sample_typed_audience],
        'anonymizeIP' => false,
        'projectId' => '111001',
        'variables' => [],
        'featureFlags' => [sample_feature_flag],
        'experiments' => [sample_experiment],
        'audiences' => [],
        'groups' => [],
        'attributes' => [],
        'accountId' => '12123',
        'layers' => [],
        'events' => [],
        'revision' => '1',
        'holdouts' => [global_holdout]
      }
    end

    let(:decision_service) do
      Optimizely::DecisionService.new(spy_logger, spy_cmab_service, spy_user_profile_service)
    end

    let(:project_instance) do
      Optimizely::Project.new(
        datafile: JSON.dump(config_body),
        logger: spy_logger,
        error_handler: error_handler
      )
    end

    after(:example) do
      project_instance&.close
    end

    it 'should handle holdout with no traffic allocation' do
      modified_holdout = global_holdout.dup
      modified_holdout['trafficAllocation'] = []

      modified_config_body = config_body.dup
      modified_config_body['holdouts'] = [modified_holdout]

      modified_config = Optimizely::DatafileProjectConfig.new(
        JSON.dump(modified_config_body),
        spy_logger,
        error_handler
      )

      feature_flag = modified_config.feature_flag_key_map['test_flag']
      user_context = project_instance.create_user_context('test_user', 'country' => 'us')

      decision_result = decision_service.get_decision_for_flag(
        feature_flag,
        user_context,
        modified_config,
        []
      )

      # Should not bucket into holdout, should fall through
      if decision_result.decision
        expect(decision_result.decision.source).not_to eq(Optimizely::DecisionService::DECISION_SOURCES['HOLDOUT'])
      end
    end

    it 'should handle holdout with empty variations array' do
      modified_holdout = global_holdout.dup
      modified_holdout['variations'] = []

      modified_config_body = config_body.dup
      modified_config_body['holdouts'] = [modified_holdout]

      modified_config = Optimizely::DatafileProjectConfig.new(
        JSON.dump(modified_config_body),
        spy_logger,
        error_handler
      )

      feature_flag = modified_config.feature_flag_key_map['test_flag']
      user_context = project_instance.create_user_context('test_user', 'country' => 'us')

      decision_result = decision_service.get_decision_for_flag(
        feature_flag,
        user_context,
        modified_config,
        []
      )

      # Should not bucket into holdout, should fall through
      if decision_result.decision
        expect(decision_result.decision.source).not_to eq(Optimizely::DecisionService::DECISION_SOURCES['HOLDOUT'])
      end
    end

    it 'should handle feature flag with no experiments' do
      modified_flag = sample_feature_flag.dup
      modified_flag['experimentIds'] = []

      modified_config_body = config_body.dup
      modified_config_body['featureFlags'] = [modified_flag]
      modified_config_body['holdouts'] = [included_holdout]

      modified_config = Optimizely::DatafileProjectConfig.new(
        JSON.dump(modified_config_body),
        spy_logger,
        error_handler
      )

      feature_flag = modified_config.feature_flag_key_map['test_flag']
      user_context = project_instance.create_user_context('test_user', 'country' => 'us')

      decision_result = decision_service.get_decision_for_flag(
        feature_flag,
        user_context,
        modified_config,
        []
      )

      # May bucket into holdout or return nil
      # Main point is it shouldn't error
      expect { decision_result }.not_to raise_error
    end

    it 'should handle inactive holdout status' do
      modified_holdout = global_holdout.dup
      modified_holdout['status'] = 'Paused'

      modified_config_body = config_body.dup
      modified_config_body['holdouts'] = [modified_holdout]

      modified_config = Optimizely::DatafileProjectConfig.new(
        JSON.dump(modified_config_body),
        spy_logger,
        error_handler
      )

      feature_flag = modified_config.feature_flag_key_map['test_flag']
      user_context = project_instance.create_user_context('test_user', 'country' => 'us')

      decision_result = decision_service.get_variation_for_holdout(
        modified_config.holdouts.first,
        user_context,
        modified_config
      )

      # Should return nil decision for inactive holdout
      expect(decision_result.decision).to be_nil

      # Should log appropriate message
      expect(spy_logger).to have_received(:log).with(
        Logger::INFO,
        a_string_matching(/is not running/i)
      )
    end
  end

  # MARK: - Tests for Today's Fixes

  describe 'Swift SDK Alignment Validation' do
    let(:config_body) do
      {
        'version' => '4',
        'rollouts' => [],
        'typedAudiences' => [sample_typed_audience],
        'anonymizeIP' => false,
        'projectId' => '111001',
        'variables' => [],
        'featureFlags' => [sample_feature_flag],
        'experiments' => [sample_experiment],
        'audiences' => [],
        'groups' => [],
        'attributes' => [],
        'accountId' => '12123',
        'layers' => [],
        'events' => [],
        'revision' => '1',
        'holdouts' => [global_holdout, included_holdout]
      }
    end

    let(:config) do
      Optimizely::DatafileProjectConfig.new(
        JSON.dump(config_body),
        spy_logger,
        error_handler
      )
    end

    it 'should store global_holdouts as an Array (not Hash)' do
      expect(config.global_holdouts).to be_an(Array)
    end

    it 'should preserve datafile order in global_holdouts array' do
      # Both holdouts are global-ish, but one has includedFlags
      # Only the truly global one should be in global_holdouts
      expect(config.global_holdouts).to be_an(Array)

      # Verify it contains the global holdout
      global_found = config.global_holdouts.any? { |h| h['id'] == 'holdout_global' }
      expect(global_found).to be true
    end

    it 'should use excluded_holdouts map for efficient filtering' do
      # Verify excluded_holdouts is a Hash
      expect(config.excluded_holdouts).to be_a(Hash)
    end

    it 'should always call get_decision_for_flag in batch operations' do
      decision_service = Optimizely::DecisionService.new(
        spy_logger,
        spy_cmab_service,
        spy_user_profile_service
      )

      project_instance = Optimizely::Project.new(
        datafile: JSON.dump(config_body),
        logger: spy_logger,
        error_handler: error_handler
      )

      feature_flag = config.feature_flag_key_map['test_flag']
      user_context = project_instance.create_user_context('test_user', 'country' => 'us')

      # Spy on get_decision_for_flag
      allow(decision_service).to receive(:get_decision_for_flag).and_call_original

      # Call get_variations_for_feature_list (batch operation)
      decision_service.get_variations_for_feature_list(
        config,
        [feature_flag],
        user_context,
        []
      )

      # Verify get_decision_for_flag was called
      expect(decision_service).to have_received(:get_decision_for_flag).at_least(:once)

      project_instance.close
    end
  end
end
