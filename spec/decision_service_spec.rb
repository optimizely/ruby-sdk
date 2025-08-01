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

  describe '#get_variation' do
    before(:example) do
      # stub out bucketer and audience evaluator so we can make sure they are / aren't called
      allow(decision_service.bucketer).to receive(:bucket).and_call_original
      allow(decision_service).to receive(:get_whitelisted_variation_id).and_call_original
      allow(Optimizely::Audience).to receive(:user_meets_audience_conditions?).and_call_original

      # by default, spy user profile service should no-op. we override this behavior in specific tests
      allow(spy_user_profile_service).to receive(:lookup).and_return(nil)
    end

    it 'should return the correct variation ID for a given user for whom a variation has been forced' do
      decision_service.set_forced_variation(config, 'test_experiment', 'test_user', 'variation')
      user_context = project_instance.create_user_context('test_user')
      variation_result = decision_service.get_variation(config, '111127', user_context)
      expect(variation_result.variation_id).to eq('111129')
      expect(variation_result.reasons).to eq(["Variation 'variation' is mapped to experiment '111127' and user 'test_user' in the forced variation map"])
      # Setting forced variation should short circuit whitelist check, bucketing and audience evaluation
      expect(decision_service).not_to have_received(:get_whitelisted_variation_id)
      expect(decision_service.bucketer).not_to have_received(:bucket)
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
    end

    it 'should return the correct variation ID (using Bucketing ID attrbiute) for a given user for whom a variation has been forced' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 'pid'
      }
      decision_service.set_forced_variation(config, 'test_experiment_with_audience', 'test_user', 'control_with_audience')
      user_context = project_instance.create_user_context('test_user', user_attributes)
      variation_result = decision_service.get_variation(config, '122227', user_context)
      expect(variation_result.variation_id).to eq('122228')
      expect(variation_result.reasons).to eq(["Variation 'control_with_audience' is mapped to experiment '122227' and user 'test_user' in the forced variation map"])
      # Setting forced variation should short circuit whitelist check, bucketing and audience evaluation
      expect(decision_service).not_to have_received(:get_whitelisted_variation_id)
      expect(decision_service.bucketer).not_to have_received(:bucket)
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
    end

    it 'should return the correct variation ID for a given user ID and key of a running experiment' do
      user_context = project_instance.create_user_context('test_user')
      user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id)
      variation_result = decision_service.get_variation(config, '111127', user_context, user_profile_tracker)
      expect(variation_result.variation_id).to eq('111128')

      expect(variation_result.reasons).to eq([
                                               "Audiences for experiment 'test_experiment' collectively evaluated to TRUE.",
                                               "User 'test_user' is in variation 'control' of experiment '111127'."
                                             ])

      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'test_user' is in variation 'control' of experiment '111127'.")
      expect(decision_service).to have_received(:get_whitelisted_variation_id).once
      expect(decision_service.bucketer).to have_received(:bucket).once
    end

    it 'should return nil when user ID is not bucketed' do
      allow(decision_service.bucketer).to receive(:bucket).and_return(nil)
      user_context = project_instance.create_user_context('test_user')
      user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id)
      variation_result = decision_service.get_variation(config, '111127', user_context, user_profile_tracker)
      expect(variation_result.variation_id).to eq(nil)
      expect(variation_result.reasons).to eq([
                                               "Audiences for experiment 'test_experiment' collectively evaluated to TRUE.",
                                               "User 'test_user' is in no variation."
                                             ])

      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'test_user' is in no variation.")
    end

    it 'should return correct variation ID if user ID is in whitelisted Variations and variation is valid' do
      user_context = project_instance.create_user_context('forced_user1')
      variation_result = decision_service.get_variation(config, '111127', user_context)
      expect(variation_result.variation_id).to eq('111128')
      expect(variation_result.reasons).to eq([
                                               "User 'forced_user1' is whitelisted into variation 'control' of experiment '111127'."
                                             ])
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'forced_user1' is whitelisted into variation 'control' of experiment '111127'.")

      user_context = project_instance.create_user_context('forced_user2')
      variation_result = decision_service.get_variation(config, '111127', user_context)
      expect(variation_result.variation_id).to eq('111129')
      expect(variation_result.reasons).to eq([
                                               "User 'forced_user2' is whitelisted into variation 'variation' of experiment '111127'."
                                             ])
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'forced_user2' is whitelisted into variation 'variation' of experiment '111127'.")

      # whitelisted variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
      # whitelisted variations should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
    end

    it 'should return correct variation ID (using Bucketing ID attrbiute) if user ID is in whitelisted Variations and variation is valid' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 'pid'
      }

      user_context = project_instance.create_user_context('forced_user1', user_attributes)
      variation_result = decision_service.get_variation(config, '111127', user_context)
      expect(variation_result.variation_id).to eq('111128')
      expect(variation_result.reasons).to eq([
                                               "User 'forced_user1' is whitelisted into variation 'control' of experiment '111127'."
                                             ])
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'forced_user1' is whitelisted into variation 'control' of experiment '111127'.")

      user_context = project_instance.create_user_context('forced_user2', user_attributes)
      variation_result = decision_service.get_variation(config, '111127', user_context)
      expect(variation_result.variation_id).to eq('111129')
      expect(variation_result.reasons).to eq([
                                               "User 'forced_user2' is whitelisted into variation 'variation' of experiment '111127'."
                                             ])
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'forced_user2' is whitelisted into variation 'variation' of experiment '111127'.")

      # whitelisted variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
      # whitelisted variations should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
    end

    it 'should return the correct variation ID for a user in a whitelisted variation (even when audience conditions do not match)' do
      user_attributes = {'browser_type' => 'wrong_browser'}
      user_context = project_instance.create_user_context('forced_audience_user', user_attributes)
      variation_result = decision_service.get_variation(config, '122227', user_context)
      expect(variation_result.variation_id).to eq('122229')
      expect(variation_result.reasons).to eq([
                                               "User 'forced_audience_user' is whitelisted into variation 'variation_with_audience' of experiment '122227'."
                                             ])
      expect(spy_logger).to have_received(:log)
        .once.with(
          Logger::INFO,
          "User 'forced_audience_user' is whitelisted into variation 'variation_with_audience' of experiment '122227'."
        )

      # forced variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
      # forced variations should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
    end

    it 'should return nil if the experiment key is invalid' do
      user_context = project_instance.create_user_context('test_user', {})
      variation_result = decision_service.get_variation(config, 'totally_invalid_experiment', user_context)
      expect(variation_result.variation_id).to eq(nil)
      expect(variation_result.reasons).to eq([])

      expect(spy_logger).to have_received(:log)
        .once.with(Logger::ERROR, "Experiment id 'totally_invalid_experiment' is not in datafile.")
    end

    it 'should return nil if the user does not meet the audience conditions for a given experiment' do
      user_attributes = {'browser_type' => 'chrome'}
      user_context = project_instance.create_user_context('test_user', user_attributes)
      user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id)
      variation_result = decision_service.get_variation(config, '122227', user_context, user_profile_tracker)
      expect(variation_result.variation_id).to eq(nil)
      expect(variation_result.reasons).to eq([
                                               "Starting to evaluate audience '11154' with conditions: [\"and\", [\"or\", [\"or\", {\"name\": \"browser_type\", \"type\": \"custom_attribute\", \"value\": \"firefox\"}]]].",
                                               "Audience '11154' evaluated to FALSE.",
                                               "Audiences for experiment 'test_experiment_with_audience' collectively evaluated to FALSE.",
                                               "User 'test_user' does not meet the conditions to be in experiment 'test_experiment_with_audience'."
                                             ])
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'test_user' does not meet the conditions to be in experiment 'test_experiment_with_audience'.")

      # should have checked forced variations
      expect(decision_service).to have_received(:get_whitelisted_variation_id).once
      # wrong audience conditions should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
    end

    it 'should return nil if the given experiment is not running' do
      user_context = project_instance.create_user_context('test_user')
      variation_result = decision_service.get_variation(config, '100027', user_context)
      expect(variation_result.variation_id).to eq(nil)
      expect(variation_result.reasons).to eq(["Experiment 'test_experiment_not_started' is not running."])
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "Experiment 'test_experiment_not_started' is not running.")

      # non-running experiments should short circuit whitelisting
      expect(decision_service).not_to have_received(:get_whitelisted_variation_id)
      # non-running experiments should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
      # non-running experiments should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
    end

    it 'should respect forced variations within mutually exclusive grouped experiments' do
      user_context = project_instance.create_user_context('forced_group_user1')
      variation_result = decision_service.get_variation(config, '133332', user_context)
      expect(variation_result.variation_id).to eq('130004')
      expect(variation_result.reasons).to eq([
                                               "User 'forced_group_user1' is whitelisted into variation 'g1_e2_v2' of experiment '133332'."
                                             ])
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'forced_group_user1' is whitelisted into variation 'g1_e2_v2' of experiment '133332'.")

      # forced variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
      # forced variations should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
    end

    it 'should bucket normally if user is whitelisted into a forced variation that is not in the datafile' do
      user_context = project_instance.create_user_context('forced_user_with_invalid_variation')
      user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id)
      variation_result = decision_service.get_variation(config, '111127', user_context, user_profile_tracker)
      expect(variation_result.variation_id).to eq('111128')
      expect(variation_result.reasons).to eq([
                                               "User 'forced_user_with_invalid_variation' is whitelisted into variation 'invalid_variation', which is not in the datafile.",
                                               "Audiences for experiment 'test_experiment' collectively evaluated to TRUE.",
                                               "User 'forced_user_with_invalid_variation' is in variation 'control' of experiment '111127'."
                                             ])
      expect(spy_logger).to have_received(:log)
        .once.with(
          Logger::INFO,
          "User 'forced_user_with_invalid_variation' is whitelisted into variation 'invalid_variation', which is not in the datafile."
        )
      # bucketing should have occured
      experiment = config.get_experiment_from_key('test_experiment')
      # since we do not pass bucketing id attribute, bucketer will recieve user id as the bucketing id
      expect(decision_service.bucketer).to have_received(:bucket).once.with(config, experiment, 'forced_user_with_invalid_variation', 'forced_user_with_invalid_variation')
    end

    describe 'when a UserProfile service is provided' do
      it 'bucket normally (using Bucketing ID attribute)' do
        user_attributes = {
          'browser_type' => 'firefox',
          Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 'pid'
        }
        user_context = project_instance.create_user_context('test_user', user_attributes)
        user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id, spy_user_profile_service, spy_logger)
        variation_result = decision_service.get_variation(config, '111127', user_context, user_profile_tracker)
        expect(variation_result.variation_id).to eq('111129')
        expect(variation_result.reasons).to eq([
                                                 "Audiences for experiment 'test_experiment' collectively evaluated to TRUE.",
                                                 "User 'test_user' is in variation 'variation' of experiment '111127'."
                                               ])

        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once
      end

      it 'skip normal bucketing if a profile with a saved decision is found' do
        saved_user_profile = {
          user_id: 'test_user',
          experiment_bucket_map: {
            '111127' => {
              variation_id: '111129'
            }
          }
        }
        expect(spy_user_profile_service).to receive(:lookup)
          .with('test_user').once.and_return(saved_user_profile)

        user_context = project_instance.create_user_context('test_user')
        user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id, spy_user_profile_service, spy_logger)
        user_profile_tracker.load_user_profile
        variation_result = decision_service.get_variation(config, '111127', user_context, user_profile_tracker)
        expect(variation_result.variation_id).to eq('111129')
        expect(variation_result.reasons).to eq([
                                                 "Returning previously activated variation ID 111129 of experiment 'test_experiment' for user 'test_user' from user profile."
                                               ])
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::INFO, "Returning previously activated variation ID 111129 of experiment 'test_experiment' for user 'test_user' from user profile.")

        # saved user profiles should short circuit bucketing
        expect(decision_service.bucketer).not_to have_received(:bucket)
        # saved user profiles should short circuit audience evaluation
        expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
        # the user profile should not be updated if bucketing did not take place
        expect(spy_user_profile_service).not_to have_received(:save)
      end

      it 'bucket normally if a profile without a saved decision is found' do
        saved_user_profile = {
          user_id: 'test_user',
          experiment_bucket_map: {
            # saved decision, but not for this experiment
            '122227' => {
              variation_id: '122228'
            }
          }
        }
        expect(spy_user_profile_service).to receive(:lookup)
          .once.with('test_user').and_return(saved_user_profile)

        user_context = project_instance.create_user_context('test_user')
        user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id, spy_user_profile_service, spy_logger)
        user_profile_tracker.load_user_profile
        variation_result = decision_service.get_variation(config, '111127', user_context, user_profile_tracker)
        expect(variation_result.variation_id).to eq('111128')
        expect(variation_result.reasons).to eq([
                                                 "Audiences for experiment 'test_experiment' collectively evaluated to TRUE.",
                                                 "User 'test_user' is in variation 'control' of experiment '111127'."
                                               ])

        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once
      end

      it 'should bucket normally if the user profile contains a variation ID not in the datafile' do
        saved_user_profile = {
          user_id: 'test_user',
          experiment_bucket_map: {
            # saved decision, but with invalid variation ID
            '111127' => {
              variation_id: '111111'
            }
          }
        }
        expect(spy_user_profile_service).to receive(:lookup)
          .once.with('test_user').and_return(saved_user_profile)

        user_context = project_instance.create_user_context('test_user')
        user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id, spy_user_profile_service, spy_logger)
        user_profile_tracker.load_user_profile
        variation_result = decision_service.get_variation(config, '111127', user_context, user_profile_tracker)
        expect(variation_result.variation_id).to eq('111128')
        expect(variation_result.reasons).to eq([
                                                 "User 'test_user' was previously bucketed into variation ID '111111' for experiment '111127', but no matching variation was found. Re-bucketing user.",
                                                 "Audiences for experiment 'test_experiment' collectively evaluated to TRUE.",
                                                 "User 'test_user' is in variation 'control' of experiment '111127'."
                                               ])

        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once
      end

      it 'should bucket normally if the user profile tracker throws an error during lookup' do
        expect(spy_user_profile_service).to receive(:lookup).once.with('test_user').and_throw(:LookupError)

        user_context = project_instance.create_user_context('test_user')
        user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id, spy_user_profile_service, spy_logger)
        user_profile_tracker.load_user_profile
        variation_result = decision_service.get_variation(config, '111127', user_context, user_profile_tracker)
        user_profile_tracker.save_user_profile
        expect(variation_result.variation_id).to eq('111128')
        expect(variation_result.reasons).to eq([
                                                 "Audiences for experiment 'test_experiment' collectively evaluated to TRUE.",
                                                 "User 'test_user' is in variation 'control' of experiment '111127'."
                                               ])

        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::ERROR, "Error while looking up user profile for user ID 'test_user': uncaught throw :LookupError.")
        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once
      end

      describe 'IGNORE_USER_PROFILE_SERVICE decide option' do
        it 'should ignore user profile service if this option is set' do
          allow(spy_user_profile_service).to receive(:lookup)
            .with('test_user').once.and_return(nil)

          user_context = project_instance.create_user_context('test_user', nil)
          user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id, spy_user_profile_service, spy_logger)
          user_profile_tracker.load_user_profile
          variation_result = decision_service.get_variation(config, '111127', user_context, user_profile_tracker, [Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE])
          expect(variation_result.variation_id).to eq('111128')
          expect(variation_result.reasons).to eq([
                                                   "Audiences for experiment 'test_experiment' collectively evaluated to TRUE.",
                                                   "User 'test_user' is in variation 'control' of experiment '111127'."
                                                 ])

          expect(decision_service.bucketer).to have_received(:bucket)
          expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?)
        end
      end
    end
  end

  describe '#get_variation_for_feature_experiment' do
    config_body_json = OptimizelySpec::VALID_CONFIG_BODY_JSON
    project_instance = Optimizely::Project.new(datafile: config_body_json)
    user_context = project_instance.create_user_context('user_1', {})
    user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id)
    describe 'when the feature flag\'s experiment ids array is empty' do
      it 'should return nil and log a message' do
        feature_flag = config.feature_flag_key_map['empty_feature']
        decision_result = decision_service.get_variation_for_feature_experiment(config, feature_flag, user_context, user_profile_tracker)
        expect(decision_result.decision).to eq(nil)
        expect(decision_result.reasons).to eq(["The feature flag 'empty_feature' is not used in any experiments."])

        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::DEBUG, "The feature flag 'empty_feature' is not used in any experiments.")
      end
    end

    describe 'and the experiment is not in the datafile' do
      it 'should return nil and log a message' do
        feature_flag = config.feature_flag_key_map['boolean_feature'].dup
        # any string that is not an experiment id in the data file
        feature_flag['experimentIds'] = ['1333333337']
        user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id)
        decision_result = decision_service.get_variation_for_feature_experiment(config, feature_flag, user_context, user_profile_tracker)
        expect(decision_result.decision).to eq(nil)
        expect(decision_result.reasons).to eq(["Feature flag experiment with ID '1333333337' is not in the datafile."])
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::DEBUG, "Feature flag experiment with ID '1333333337' is not in the datafile.")
      end
    end

    describe 'when the feature flag is associated with a non-mutex experiment' do
      user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id)
      describe 'and the user is not bucketed into the feature flag\'s experiments' do
        before(:each) do
          multivariate_experiment = config.experiment_key_map['test_experiment_multivariate']
          # make sure the user is not bucketed into the feature experiment
          allow(decision_service).to receive(:get_variation)
            .with(config, multivariate_experiment['id'], user_context, user_profile_tracker, [])
            .and_return(Optimizely::DecisionService::VariationResult.new(nil, false, [], nil))
        end

        it 'should return nil and log a message' do
          feature_flag = config.feature_flag_key_map['multi_variate_feature']
          decision_result = decision_service.get_variation_for_feature_experiment(config, feature_flag, user_context, user_profile_tracker, [])
          expect(decision_result.decision).to eq(nil)
          expect(decision_result.reasons).to eq(["The user 'user_1' is not bucketed into any of the experiments on the feature 'multi_variate_feature'."])

          expect(spy_logger).to have_received(:log).once
                                                   .with(Logger::INFO, "The user 'user_1' is not bucketed into any of the experiments on the feature 'multi_variate_feature'.")
        end
      end

      describe 'and the user is bucketed into a variation for the experiment on the feature flag' do
        before(:each) do
          # mock and return the first variation of the `test_experiment_multivariate` experiment, which is attached to the `multi_variate_feature`
          allow(decision_service).to receive(:get_variation).and_return(Optimizely::DecisionService::VariationResult.new(nil, false, [], '122231'))
        end

        it 'should return the variation' do
          feature_flag = config.feature_flag_key_map['multi_variate_feature']
          expected_decision = Optimizely::DecisionService::Decision.new(
            config.experiment_key_map['test_experiment_multivariate'],
            config.variation_id_map['test_experiment_multivariate']['122231'],
            Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          )
          expected_decision_result = Optimizely::DecisionService::DecisionResult.new(
            expected_decision,
            false,
            []
          )
          user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id)
          decision_result = decision_service.get_variation_for_feature_experiment(config, feature_flag, user_context, user_profile_tracker)
          expect(decision_result).to eq(expected_decision_result)
          expect(decision_result.reasons).to eq([])
        end
      end
    end

    describe 'when the feature flag is associated with a mutex experiment' do
      mutex_exp = nil
      expected_decision = nil
      describe 'and the user is bucketed into one of the experiments' do
        before(:each) do
          mutex_exp = config.experiment_key_map['group1_exp1']
          variation = mutex_exp['variations'][0]
          expected_decision = Optimizely::DecisionService::Decision.new(
            mutex_exp,
            variation,
            Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          )
          allow(decision_service).to receive(:get_variation)
            .and_return(Optimizely::DecisionService::VariationResult.new(nil, false, [], variation['id']))
        end

        it 'should return the variation the user is bucketed into' do
          feature_flag = config.feature_flag_key_map['mutex_group_feature']
          user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id)
          decision_result = decision_service.get_variation_for_feature_experiment(config, feature_flag, user_context, user_profile_tracker)
          expect(decision_result.decision).to eq(expected_decision)
          expect(decision_result.reasons).to eq([])
        end
      end

      describe 'and the user is not bucketed into any of the mutex experiments' do
        user_profile_tracker = Optimizely::UserProfileTracker.new(user_context.user_id)
        before(:each) do
          mutex_exp = config.experiment_key_map['group1_exp1']
          mutex_exp2 = config.experiment_key_map['group1_exp2']
          allow(decision_service).to receive(:get_variation)
            .with(config, mutex_exp['id'], user_context, user_profile_tracker, [])
            .and_return(Optimizely::DecisionService::VariationResult.new(nil, false, [], nil))
          allow(decision_service).to receive(:get_variation)
            .with(config, mutex_exp2['id'], user_context, user_profile_tracker, [])
            .and_return(Optimizely::DecisionService::VariationResult.new(nil, false, [], nil))
        end

        it 'should return nil and log a message' do
          feature_flag = config.feature_flag_key_map['mutex_group_feature']
          decision_result = decision_service.get_variation_for_feature_experiment(config, feature_flag, user_context, user_profile_tracker)
          expect(decision_result.decision).to eq(nil)
          expect(decision_result.reasons).to eq(["The user 'user_1' is not bucketed into any of the experiments on the feature 'mutex_group_feature'."])

          expect(spy_logger).to have_received(:log).once
                                                   .with(Logger::INFO, "The user 'user_1' is not bucketed into any of the experiments on the feature 'mutex_group_feature'.")
        end
      end
    end
  end

  describe '#get_variation_for_feature_rollout' do
    config_body_json = OptimizelySpec::VALID_CONFIG_BODY_JSON
    project_instance = Optimizely::Project.new(datafile: config_body_json)
    user_context = project_instance.create_user_context('user_1', {})
    user_id = 'user_1'

    describe 'when the feature flag is not associated with a rollout' do
      it 'should log a message and return nil' do
        feature_flag = config.feature_flag_key_map['boolean_feature']
        decision_result = decision_service.get_variation_for_feature_rollout(config, feature_flag, user_context)
        expect(decision_result.decision).to eq(nil)
        expect(decision_result.reasons).to eq(["Feature flag '#{feature_flag['key']}' is not used in a rollout."])
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::DEBUG, "Feature flag '#{feature_flag['key']}' is not used in a rollout.")
      end
    end

    describe 'when the rollout is not in the datafile' do
      it 'should log a message and return nil' do
        feature_flag = config.feature_flag_key_map['boolean_feature'].dup
        feature_flag['rolloutId'] = 'invalid_rollout_id'
        decision_result = decision_service.get_variation_for_feature_rollout(config, feature_flag, user_context)
        expect(decision_result.decision).to eq(nil)
        expect(decision_result.reasons).to eq(["Rollout with ID 'invalid_rollout_id' is not in the datafile 'boolean_feature'"])

        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::ERROR, "Rollout with ID 'invalid_rollout_id' is not in the datafile.")
      end
    end

    describe 'when the rollout does not have any experiments' do
      it 'should return nil' do
        experimentless_rollout = config.rollouts[0].dup
        experimentless_rollout['experiments'] = []
        allow(config).to receive(:get_rollout_from_id).and_return(experimentless_rollout)
        feature_flag = config.feature_flag_key_map['boolean_single_variable_feature']
        decision_result = decision_service.get_variation_for_feature_rollout(config, feature_flag, user_context)
        expect(decision_result.decision).to eq(nil)
        expect(decision_result.reasons).to eq([])
      end
    end

    describe 'when the user qualifies for targeting rule' do
      describe 'and the user is bucketed into the targeting rule' do
        it 'should return the variation the user is bucketed into' do
          feature_flag = config.feature_flag_key_map['boolean_single_variable_feature']
          rollout_experiment = config.rollout_id_map[feature_flag['rolloutId']]['experiments'][0]
          variation = rollout_experiment['variations'][0]
          expected_decision = Optimizely::DecisionService::Decision.new(rollout_experiment, variation, Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT'])
          allow(Optimizely::Audience).to receive(:user_meets_audience_conditions?).and_return(true)
          allow(decision_service.bucketer).to receive(:bucket)
            .with(config, rollout_experiment, user_id, user_id)
            .and_return(variation)
          decision_result = decision_service.get_variation_for_feature_rollout(config, feature_flag, user_context)
          expect(decision_result.decision).to eq(expected_decision)
          expect(decision_result.reasons).to eq(["User 'user_1' meets the audience conditions for targeting rule '1'.",
                                                 "User 'user_1' is in the traffic group of targeting rule '1'."])
        end
      end

      describe 'and the user is not bucketed into the targeting rule' do
        describe 'and the user is not bucketed into the "Everyone Else" rule' do
          it 'should log and return nil' do
            feature_flag = config.feature_flag_key_map['boolean_single_variable_feature']
            rollout = config.rollout_id_map[feature_flag['rolloutId']]
            everyone_else_experiment = rollout['experiments'][2]

            allow(Optimizely::Audience).to receive(:user_meets_audience_conditions?).and_return(true)
            allow(decision_service.bucketer).to receive(:bucket)
              .with(config, rollout['experiments'][0], user_id, user_id)
              .and_return(nil)
            allow(decision_service.bucketer).to receive(:bucket)
              .with(config, everyone_else_experiment, user_id, user_id)
              .and_return(nil)

            decision_result = decision_service.get_variation_for_feature_rollout(config, feature_flag, user_context)
            expect(decision_result.decision).to eq(nil)
            expect(decision_result.reasons).to eq([
                                                    "User 'user_1' meets the audience conditions for targeting rule '1'.",
                                                    "User 'user_1' is not in the traffic group for targeting rule '1'.",
                                                    "User 'user_1' meets the audience conditions for targeting rule 'Everyone Else'."
                                                  ])

            # make sure we only checked the audience for the first rule
            expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?).once
                                                                                           .with(config, rollout['experiments'][0], user_context, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', '1')
            expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
              .with(config, rollout['experiments'][1], user_context, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 2)
          end
        end

        describe 'and the user is bucketed into the "Everyone Else" rule' do
          it 'should return the variation the user is bucketed into' do
            feature_flag = config.feature_flag_key_map['boolean_single_variable_feature']
            rollout = config.rollout_id_map[feature_flag['rolloutId']]
            everyone_else_experiment = rollout['experiments'][2]
            variation = everyone_else_experiment['variations'][0]
            expected_decision = Optimizely::DecisionService::Decision.new(everyone_else_experiment, variation, Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT'])
            allow(Optimizely::Audience).to receive(:user_meets_audience_conditions?).and_return(true)
            allow(decision_service.bucketer).to receive(:bucket)
              .with(config, rollout['experiments'][0], user_id, user_id)
              .and_return(nil)
            allow(decision_service.bucketer).to receive(:bucket)
              .with(config, everyone_else_experiment, user_id, user_id)
              .and_return(variation)

            decision_result = decision_service.get_variation_for_feature_rollout(config, feature_flag, user_context)
            expect(decision_result.decision).to eq(expected_decision)
            expect(decision_result.reasons).to eq([
                                                    "User 'user_1' meets the audience conditions for targeting rule '1'.",
                                                    "User 'user_1' is not in the traffic group for targeting rule '1'.",
                                                    "User 'user_1' meets the audience conditions for targeting rule 'Everyone Else'.",
                                                    "User 'user_1' is in the traffic group of targeting rule 'Everyone Else'."
                                                  ])

            # make sure we only checked the audience for the first rule
            expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?).once
                                                                                           .with(config, rollout['experiments'][0], user_context, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', '1')
            expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
              .with(config, rollout['experiments'][1], user_context, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 2)
          end
        end
      end
    end

    describe 'when the user is not bucketed into any targeting rules' do
      it 'should try to bucket the user into the "Everyone Else" rule' do
        feature_flag = config.feature_flag_key_map['boolean_single_variable_feature']
        rollout = config.rollout_id_map[feature_flag['rolloutId']]
        everyone_else_experiment = rollout['experiments'][2]
        variation = everyone_else_experiment['variations'][0]
        expected_decision = Optimizely::DecisionService::Decision.new(everyone_else_experiment, variation, Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT'])
        allow(Optimizely::Audience).to receive(:user_meets_audience_conditions?).and_return(false)

        allow(Optimizely::Audience).to receive(:user_meets_audience_conditions?)
          .with(config, everyone_else_experiment, user_context, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 'Everyone Else')
          .and_return(true)
        allow(decision_service.bucketer).to receive(:bucket)
          .with(config, everyone_else_experiment, user_id, user_id)
          .and_return(variation)

        decision_result = decision_service.get_variation_for_feature_rollout(config, feature_flag, user_context)
        expect(decision_result.decision).to eq(expected_decision)
        expect(decision_result.reasons).to eq([
                                                "User 'user_1' does not meet the conditions for targeting rule '1'.",
                                                "User 'user_1' does not meet the conditions for targeting rule '2'.",
                                                "User 'user_1' meets the audience conditions for targeting rule 'Everyone Else'.",
                                                "User 'user_1' is in the traffic group of targeting rule 'Everyone Else'."
                                              ])

        # verify we tried to bucket in all targeting rules and the everyone else rule
        expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?).exactly(3).times

        # verify log messages
        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' does not meet the conditions for targeting rule '1'.")

        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' does not meet the conditions for targeting rule '2'.")

        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' meets the audience conditions for targeting rule 'Everyone Else'.")
      end

      it 'should not bucket the user into the "Everyone Else" rule when audience mismatch' do
        feature_flag = config.feature_flag_key_map['boolean_single_variable_feature']
        rollout = config.rollout_id_map[feature_flag['rolloutId']]
        everyone_else_experiment = rollout['experiments'][2]
        everyone_else_experiment['audienceIds'] = ['11155']
        allow(Optimizely::Audience).to receive(:user_meets_audience_conditions?).and_return(false)

        expect(decision_service.bucketer).not_to receive(:bucket)
          .with(config, everyone_else_experiment, user_id, user_id)

        decision_result = decision_service.get_variation_for_feature_rollout(config, feature_flag, user_context)
        expect(decision_result.decision).to eq(nil)
        expect(decision_result.reasons).to eq([
                                                "User 'user_1' does not meet the conditions for targeting rule '1'.",
                                                "User 'user_1' does not meet the conditions for targeting rule '2'.",
                                                "User 'user_1' does not meet the conditions for targeting rule 'Everyone Else'."
                                              ])

        # verify we tried to bucket in all targeting rules and the everyone else rule
        expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?).once
                                                                                       .with(config, rollout['experiments'][0], user_context, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', '1')
        expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?)
          .with(config, rollout['experiments'][1], user_context, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', '2')
        expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?)
          .with(config, rollout['experiments'][2], user_context, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 'Everyone Else')

        # verify log messages
        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' does not meet the conditions for targeting rule '1'.")

        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' does not meet the conditions for targeting rule '2'.")

        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' does not meet the conditions for targeting rule 'Everyone Else'.")
      end
    end
  end

  describe '#get_variation_for_feature' do
    config_body_json = OptimizelySpec::VALID_CONFIG_BODY_JSON
    project_instance = Optimizely::Project.new(datafile: config_body_json)
    user_context = project_instance.create_user_context('user_1', {})

    describe 'when the user is bucketed into the feature experiment' do
      it 'should return the bucketed experiment and variation' do
        feature_flag = config.feature_flag_key_map['string_single_variable_feature']
        expected_experiment = config.experiment_id_map[feature_flag['experimentIds'][0]]
        expected_variation = expected_experiment['variations'][0]
        expected_decision = {
          'experiment' => expected_experiment,
          'variation' => expected_variation
        }
        allow(decision_service).to receive(:get_variation_for_feature_experiment).and_return(Optimizely::DecisionService::DecisionResult.new(expected_decision, false, []))

        decision_result = decision_service.get_variation_for_feature(config, feature_flag, user_context)
        expect(decision_result.decision).to eq(expected_decision)
        expect(decision_result.reasons).to eq([])
      end
    end

    describe 'when then user is not bucketed into the feature experiment' do
      describe 'and the user is bucketed into the feature rollout' do
        it 'should return the bucketed variation and nil experiment' do
          feature_flag = config.feature_flag_key_map['string_single_variable_feature']
          rollout = config.rollout_id_map[feature_flag['rolloutId']]
          variation = rollout['experiments'][0]['variations'][0]
          expected_decision = Optimizely::DecisionService::Decision.new(
            nil,
            variation,
            Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
          )
          allow(decision_service).to receive(:get_variation_for_feature_experiment).and_return(Optimizely::DecisionService::DecisionResult.new(nil, false, []))
          allow(decision_service).to receive(:get_variation_for_feature_rollout).and_return(Optimizely::DecisionService::DecisionResult.new(expected_decision, false, []))

          decision_result = decision_service.get_variation_for_feature(config, feature_flag, user_context)
          expect(decision_result.decision).to eq(expected_decision)
          expect(decision_result.reasons).to eq([])
        end
      end

      describe 'and the user is not bucketed into the feature rollout' do
        it 'should log a message and return nil' do
          feature_flag = config.feature_flag_key_map['string_single_variable_feature']
          allow(decision_service).to receive(:get_variation_for_feature_experiment).and_return(Optimizely::DecisionService::DecisionResult.new(nil, false, []))
          allow(decision_service).to receive(:get_variation_for_feature_rollout).and_return(Optimizely::DecisionService::DecisionResult.new(nil, false, []))

          decision_result = decision_service.get_variation_for_feature(config, feature_flag, user_context)
          expect(decision_result.decision).to eq(nil)
          expect(decision_result.reasons).to eq([])
        end
      end
    end
  end
  describe '#get_bucketing_id' do
    it 'should log a message and return user ID when bucketing ID is not a String' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 5
      }
      bucketing_id, reason = decision_service.send(:get_bucketing_id, 'test_user', user_attributes)
      expect(bucketing_id).to eq('test_user')
      expect(reason).to eq('Bucketing ID attribute is not a string. Defaulted to user ID.')

      expect(spy_logger).to have_received(:log).once.with(Logger::WARN, 'Bucketing ID attribute is not a string. Defaulted to user ID.')
    end

    it 'should not log any message and return user ID when bucketing ID is nil' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => nil
      }
      bucketing_id, reason = decision_service.send(:get_bucketing_id, 'test_user', user_attributes)
      expect(bucketing_id).to eq('test_user')
      expect(reason).to eq(nil)
      expect(spy_logger).not_to have_received(:log).with(Logger::WARN, anything)
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should not log any message and return given bucketing ID when bucketing ID is a String' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 'i_am_bucketing_id'
      }
      bucketing_id, reason = decision_service.send(:get_bucketing_id, 'test_user', user_attributes)
      expect(bucketing_id).to eq('i_am_bucketing_id')
      expect(reason).to eq(nil)
      expect(spy_logger).not_to have_received(:log).with(Logger::WARN, anything)
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should not log any message and return empty String when bucketing ID is empty String' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => ''
      }
      bucketing_id, reason = decision_service.send(:get_bucketing_id, 'test_user', user_attributes)
      expect(bucketing_id).to eq('')
      expect(reason).to eq(nil)
      expect(spy_logger).not_to have_received(:log).with(Logger::WARN, anything)
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end
  end

  # Only those log messages have been asserted, which are directly logged in these methods.
  # Messages that are logged in some internal function calls, are asserted in their respective function test cases.
  describe 'get_forced_variation' do
    user_id = 'test_user'
    invalid_experiment_key = 'invalid_experiment'
    valid_experiment = {id: '111127', key: 'test_experiment'}

    # User ID is not defined in the forced variation map
    it 'should log a message and return nil when user is not in forced variation map' do
      variation_received, reasons = decision_service.get_forced_variation(config, valid_experiment[:key], user_id)
      expect(variation_received).to eq(nil)
      expect(reasons).to eq([])
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG,
                                                     "User '#{user_id}' is not in the forced variation map.")
    end
    # Experiment key does not exist in the datafile
    it 'should return nil when experiment key is not in datafile' do
      variation_received, reasons = decision_service.get_forced_variation(config, invalid_experiment_key, user_id)
      expect(variation_received).to eq(nil)
      expect(reasons).to eq([])
    end
  end

  # Only those log messages have been asserted, which are directly logged in these methods.
  # Messages that are logged in some internal function calls, are asserted in their respective function test cases.
  describe 'set_forced_variation' do
    user_id = 'test_user'
    invalid_experiment_key = 'invalid_experiment'
    invalid_variation_key = 'invalid_variation'
    valid_experiment = {id: '111127', key: 'test_experiment'}
    valid_variation = {id: '111128', key: 'control'}

    # Experiment key does not exist in the datafile
    it 'return nil when experiment key is not in datafile' do
      expect(decision_service.set_forced_variation(config, invalid_experiment_key, user_id, valid_variation[:key])).to eq(false)
    end
    # Variation key does not exist in the datafile
    it 'return false when variation_key is not in datafile' do
      expect(decision_service.set_forced_variation(config, valid_experiment[:key], user_id, invalid_variation_key)).to eq(false)
    end
  end

  describe 'set/get forced variations multiple calls' do
    user_id = 'test_user'
    user_id_2 = 'test_user_2'
    valid_experiment = {id: '111127', key: 'test_experiment'}
    valid_variation = {id: '111128', key: 'control'}
    valid_variation_2 = {id: '111129', key: 'variation'}
    valid_experiment_2 = {id: '122227', key: 'test_experiment_with_audience'}
    valid_variation_for_exp_2 = {id: '122228', key: 'control_with_audience'}
    # Call set variation with different variations on one user/experiment to confirm that each set is expected.
    it 'should set and return expected variations when different variations are set and removed for one user/experiment' do
      expect(decision_service.set_forced_variation(config, valid_experiment[:key], user_id, valid_variation[:key])).to eq(true)
      variation, reasons = decision_service.get_forced_variation(config, valid_experiment[:key], user_id)
      expect(variation['id']).to eq(valid_variation[:id])
      expect(variation['key']).to eq(valid_variation[:key])
      expect(reasons).to eq(["Variation 'control' is mapped to experiment '111127' and user 'test_user' in the forced variation map"])

      expect(decision_service.set_forced_variation(config, valid_experiment[:key], user_id, valid_variation_2[:key])).to eq(true)
      variation, reasons = decision_service.get_forced_variation(config, valid_experiment[:key], user_id)
      expect(variation['id']).to eq(valid_variation_2[:id])
      expect(variation['key']).to eq(valid_variation_2[:key])
      expect(reasons).to eq(["Variation 'variation' is mapped to experiment '111127' and user 'test_user' in the forced variation map"])
    end

    # Set variation on multiple experiments for one user.
    it 'should set and return expected variations when variation is set for multiple experiments for one user' do
      expect(decision_service.set_forced_variation(config, valid_experiment[:key], user_id, valid_variation[:key])).to eq(true)
      variation, reasons = decision_service.get_forced_variation(config, valid_experiment[:key], user_id)
      expect(variation['id']).to eq(valid_variation[:id])
      expect(variation['key']).to eq(valid_variation[:key])
      expect(reasons).to eq(["Variation 'control' is mapped to experiment '111127' and user 'test_user' in the forced variation map"])

      expect(decision_service.set_forced_variation(config, valid_experiment_2[:key], user_id, valid_variation_for_exp_2[:key])).to eq(true)
      variation, reasons = decision_service.get_forced_variation(config, valid_experiment_2[:key], user_id)
      expect(variation['id']).to eq(valid_variation_for_exp_2[:id])
      expect(variation['key']).to eq(valid_variation_for_exp_2[:key])
      expect(reasons).to eq(["Variation 'control_with_audience' is mapped to experiment '122227' and user 'test_user' in the forced variation map"])
    end

    # Set variations for multiple users.
    it 'should set and return expected variations when variations are set for multiple users' do
      expect(decision_service.set_forced_variation(config, valid_experiment[:key], user_id, valid_variation[:key])).to eq(true)
      variation, reasons = decision_service.get_forced_variation(config, valid_experiment[:key], user_id)
      expect(variation['id']).to eq(valid_variation[:id])
      expect(variation['key']).to eq(valid_variation[:key])
      expect(reasons).to eq(["Variation 'control' is mapped to experiment '111127' and user 'test_user' in the forced variation map"])

      expect(decision_service.set_forced_variation(config, valid_experiment[:key], user_id_2, valid_variation[:key])).to eq(true)
      variation, reasons = decision_service.get_forced_variation(config, valid_experiment[:key], user_id_2)
      expect(variation['id']).to eq(valid_variation[:id])
      expect(variation['key']).to eq(valid_variation[:key])
      expect(reasons).to eq(["Variation 'control' is mapped to experiment '111127' and user 'test_user_2' in the forced variation map"])
    end
  end
  describe 'CMAB experiments' do
    describe 'when user is in traffic allocation' do
      it 'should return correct variation and CMAB UUID from CMAB service' do
        # Create a CMAB experiment configuration
        cmab_experiment = {
          'id' => '111150',
          'key' => 'cmab_experiment',
          'status' => 'Running',
          'layerId' => '111150',
          'audienceIds' => [],
          'forcedVariations' => {},
          'variations' => [
            {'id' => '111151', 'key' => 'variation_1'},
            {'id' => '111152', 'key' => 'variation_2'}
          ],
          'trafficAllocation' => [
            {'entityId' => '111151', 'endOfRange' => 5000},
            {'entityId' => '111152', 'endOfRange' => 10_000}
          ],
          'cmab' => {'trafficAllocation' => 5000}
        }
        user_context = project_instance.create_user_context('test_user', {})

        # Mock experiment lookup to return our CMAB experiment
        allow(config).to receive(:get_experiment_from_id).with('111150').and_return(cmab_experiment)
        allow(config).to receive(:experiment_running?).with(cmab_experiment).and_return(true)

        # Mock audience evaluation to pass
        allow(Optimizely::Audience).to receive(:user_meets_audience_conditions?).and_return([true, []])

        # Mock bucketer to return a valid entity ID (user is in traffic allocation)
        allow(decision_service.bucketer).to receive(:bucket_to_entity_id)
          .with(config, cmab_experiment, 'test_user', 'test_user')
          .and_return(['$', []])

        # Mock CMAB service to return a decision
        allow(spy_cmab_service).to receive(:get_decision)
          .with(config, user_context, '111150', [])
          .and_return(Optimizely::CmabDecision.new(variation_id: '111151', cmab_uuid: 'test-cmab-uuid-123'))

        # Mock variation lookup
        allow(config).to receive(:get_variation_from_id_by_experiment_id)
          .with('111150', '111151')
          .and_return({'id' => '111151', 'key' => 'variation_1'})

        variation_result = decision_service.get_variation(config, '111150', user_context)

        expect(variation_result.variation_id).to eq('111151')
        expect(variation_result.cmab_uuid).to eq('test-cmab-uuid-123')
        expect(variation_result.error).to eq(false)
        expect(variation_result.reasons).to include(
          "User 'test_user' is in variation 'variation_1' of experiment '111150'."
        )

        # Verify CMAB service was called
        expect(spy_cmab_service).to have_received(:get_decision).once
      end
    end

    describe 'when user is not in traffic allocation' do
      it 'should return nil variation and log traffic allocation message' do
        cmab_experiment = {
          'id' => '111150',
          'key' => 'cmab_experiment',
          'status' => 'Running',
          'layerId' => '111150',
          'audienceIds' => [],
          'forcedVariations' => {},
          'variations' => [
            {'id' => '111151', 'key' => 'variation_1'}
          ],
          'trafficAllocation' => [
            {'entityId' => '111151', 'endOfRange' => 10_000}
          ],
          'cmab' => {'trafficAllocation' => 1000}
        }
        user_context = project_instance.create_user_context('test_user', {})

        # Mock experiment lookup to return our CMAB experiment
        allow(config).to receive(:get_experiment_from_id).with('111150').and_return(cmab_experiment)
        allow(config).to receive(:experiment_running?).with(cmab_experiment).and_return(true)

        # Mock audience evaluation to pass
        allow(Optimizely::Audience).to receive(:user_meets_audience_conditions?).and_return([true, []])

        variation_result = decision_service.get_variation(config, '111150', user_context)

        expect(variation_result.variation_id).to eq(nil)
        expect(variation_result.cmab_uuid).to eq(nil)
        expect(variation_result.error).to eq(false)
        expect(variation_result.reasons).to include(
          'User "test_user" not in CMAB experiment "cmab_experiment" due to traffic allocation.'
        )

        # Verify CMAB service was not called since user is not in traffic allocation
        expect(spy_cmab_service).not_to have_received(:get_decision)
      end
    end

    describe 'when CMAB service returns an error' do
      it 'should return nil variation and include error in reasons' do
        cmab_experiment = {
          'id' => '111150',
          'key' => 'cmab_experiment',
          'status' => 'Running',
          'layerId' => '111150',
          'audienceIds' => [],
          'forcedVariations' => {},
          'variations' => [
            {'id' => '111151', 'key' => 'variation_1'}
          ],
          'trafficAllocation' => [
            {'entityId' => '111151', 'endOfRange' => 10_000}
          ],
          'cmab' => {'trafficAllocation' => 5000}
        }
        user_context = project_instance.create_user_context('test_user', {})

        # Mock experiment lookup to return our CMAB experiment
        allow(config).to receive(:get_experiment_from_id).with('111150').and_return(cmab_experiment)
        allow(config).to receive(:experiment_running?).with(cmab_experiment).and_return(true)

        # Mock audience evaluation to pass
        allow(Optimizely::Audience).to receive(:user_meets_audience_conditions?).and_return([true, []])

        # Mock bucketer to return a valid entity ID (user is in traffic allocation)
        allow(decision_service.bucketer).to receive(:bucket_to_entity_id)
          .with(config, cmab_experiment, 'test_user', 'test_user')
          .and_return(['$', []])

        # Mock CMAB service to return an error
        allow(spy_cmab_service).to receive(:get_decision)
          .with(config, user_context, '111150', [])
          .and_raise(StandardError.new('CMAB service error'))

        variation_result = decision_service.get_variation(config, '111150', user_context)

        expect(variation_result.variation_id).to be_nil
        expect(variation_result.cmab_uuid).to be_nil
        expect(variation_result.error).to eq(true)
        expect(variation_result.reasons).to include(
          "Failed to fetch CMAB decision for experiment 'cmab_experiment'"
        )

        # Verify CMAB service was called but errored
        expect(spy_cmab_service).to have_received(:get_decision).once
      end
    end

    describe 'when user has forced variation' do
      it 'should return forced variation and skip CMAB service call' do
        # Use a real experiment from the datafile and modify it to be a CMAB experiment
        real_experiment = config.get_experiment_from_key('test_experiment')
        cmab_experiment = real_experiment.dup
        cmab_experiment['cmab'] = {'trafficAllocation' => 5000}

        user_context = project_instance.create_user_context('test_user', {})

        # Set up forced variation first (using real experiment that exists in datafile)
        decision_service.set_forced_variation(config, 'test_experiment', 'test_user', 'variation')

        # Mock the experiment to be a CMAB experiment after setting forced variation
        allow(config).to receive(:get_experiment_from_id).with('111127').and_return(cmab_experiment)
        allow(config).to receive(:experiment_running?).with(cmab_experiment).and_return(true)

        # Add spy for bucket_to_entity_id method
        allow(decision_service.bucketer).to receive(:bucket_to_entity_id).and_call_original

        variation_result = decision_service.get_variation(config, '111127', user_context)

        expect(variation_result.variation_id).to eq('111129')
        expect(variation_result.cmab_uuid).to be_nil
        expect(variation_result.error).to eq(false)
        expect(variation_result.reasons).to include(
          "Variation 'variation' is mapped to experiment '111127' and user 'test_user' in the forced variation map"
        )

        # Verify CMAB service was not called since user has forced variation
        expect(spy_cmab_service).not_to have_received(:get_decision)
        # Verify bucketer was not called since forced variations short-circuit bucketing
        expect(decision_service.bucketer).not_to have_received(:bucket_to_entity_id)
      end
    end

    describe 'when user has whitelisted variation' do
      it 'should return whitelisted variation and skip CMAB service call' do
        # Create a CMAB experiment with whitelisted users
        cmab_experiment = {
          'id' => '111150',
          'key' => 'cmab_experiment',
          'status' => 'Running',
          'layerId' => '111150',
          'audienceIds' => [],
          'forcedVariations' => {
            'whitelisted_user' => '111151' # User is whitelisted to variation_1
          },
          'variations' => [
            {'id' => '111151', 'key' => 'variation_1'},
            {'id' => '111152', 'key' => 'variation_2'}
          ],
          'trafficAllocation' => [
            {'entityId' => '111151', 'endOfRange' => 5000},
            {'entityId' => '111152', 'endOfRange' => 10_000}
          ],
          'cmab' => {'trafficAllocation' => 5000}
        }
        user_context = project_instance.create_user_context('whitelisted_user', {})

        # Mock experiment lookup to return our CMAB experiment
        allow(config).to receive(:get_experiment_from_id).with('111150').and_return(cmab_experiment)
        allow(config).to receive(:experiment_running?).with(cmab_experiment).and_return(true)

        # Mock the get_whitelisted_variation_id method directly
        allow(decision_service).to receive(:get_whitelisted_variation_id)
          .with(config, '111150', 'whitelisted_user')
          .and_return(['111151', "User 'whitelisted_user' is whitelisted into variation 'variation_1' of experiment '111150'."])

        variation_result = decision_service.get_variation(config, '111150', user_context)

        expect(variation_result.variation_id).to eq('111151')
        expect(variation_result.cmab_uuid).to be_nil
        expect(variation_result.error).to eq(false)
        expect(variation_result.reasons).to include(
          "User 'whitelisted_user' is whitelisted into variation 'variation_1' of experiment '111150'."
        )
        # Verify CMAB service was not called since user is whitelisted
        expect(spy_cmab_service).not_to have_received(:get_decision)
      end
    end
  end
end
