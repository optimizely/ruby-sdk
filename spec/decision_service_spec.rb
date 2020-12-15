# frozen_string_literal: true

#
#    Copyright 2017-2020, Optimizely and contributors
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
  let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:decision_service) { Optimizely::DecisionService.new(spy_logger, spy_user_profile_service) }

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
      expect(decision_service.get_variation(config, 'test_experiment', 'test_user')).to eq('111129')
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
      expect(decision_service.get_variation(config, 'test_experiment_with_audience', 'test_user', user_attributes)).to eq('122228')
      # Setting forced variation should short circuit whitelist check, bucketing and audience evaluation
      expect(decision_service).not_to have_received(:get_whitelisted_variation_id)
      expect(decision_service.bucketer).not_to have_received(:bucket)
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
    end

    it 'should return the correct variation ID for a given user ID and key of a running experiment' do
      expect(decision_service.get_variation(config, 'test_experiment', 'test_user')).to eq('111128')

      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'test_user' is in variation 'control' of experiment 'test_experiment'.")
      expect(decision_service).to have_received(:get_whitelisted_variation_id).once
      expect(decision_service.bucketer).to have_received(:bucket).once
    end

    it 'should return nil when user ID is not bucketed' do
      allow(decision_service.bucketer).to receive(:bucket).and_return(nil)
      expect(decision_service.get_variation(config, 'test_experiment', 'test_user')).to eq(nil)

      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'test_user' is in no variation.")
    end

    it 'should return correct variation ID if user ID is in whitelisted Variations and variation is valid' do
      expect(decision_service.get_variation(config, 'test_experiment', 'forced_user1')).to eq('111128')
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'forced_user1' is whitelisted into variation 'control' of experiment 'test_experiment'.")

      expect(decision_service.get_variation(config, 'test_experiment', 'forced_user2')).to eq('111129')
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'forced_user2' is whitelisted into variation 'variation' of experiment 'test_experiment'.")

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
      expect(decision_service.get_variation(config, 'test_experiment', 'forced_user1', user_attributes)).to eq('111128')
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'forced_user1' is whitelisted into variation 'control' of experiment 'test_experiment'.")

      expect(decision_service.get_variation(config, 'test_experiment', 'forced_user2', user_attributes)).to eq('111129')
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'forced_user2' is whitelisted into variation 'variation' of experiment 'test_experiment'.")

      # whitelisted variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
      # whitelisted variations should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
    end

    it 'should return the correct variation ID for a user in a whitelisted variation (even when audience conditions do not match)' do
      user_attributes = {'browser_type' => 'wrong_browser'}
      expect(decision_service.get_variation(config, 'test_experiment_with_audience', 'forced_audience_user', user_attributes)).to eq('122229')
      expect(spy_logger).to have_received(:log)
        .once.with(
          Logger::INFO,
          "User 'forced_audience_user' is whitelisted into variation 'variation_with_audience' of experiment 'test_experiment_with_audience'."
        )

      # forced variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
      # forced variations should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
    end

    it 'should return nil if the experiment key is invalid' do
      expect(decision_service.get_variation(config, 'totally_invalid_experiment', 'test_user', {})).to eq(nil)

      expect(spy_logger).to have_received(:log)
        .once.with(Logger::ERROR, "Experiment key 'totally_invalid_experiment' is not in datafile.")
    end

    it 'should return nil if the user does not meet the audience conditions for a given experiment' do
      user_attributes = {'browser_type' => 'chrome'}
      expect(decision_service.get_variation(config, 'test_experiment_with_audience', 'test_user', user_attributes)).to eq(nil)
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'test_user' does not meet the conditions to be in experiment 'test_experiment_with_audience'.")

      # should have checked forced variations
      expect(decision_service).to have_received(:get_whitelisted_variation_id).once
      # wrong audience conditions should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
    end

    it 'should return nil if the given experiment is not running' do
      expect(decision_service.get_variation(config, 'test_experiment_not_started', 'test_user')).to eq(nil)
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
      expect(decision_service.get_variation(config, 'group1_exp2', 'forced_group_user1')).to eq('130004')
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::INFO, "User 'forced_group_user1' is whitelisted into variation 'g1_e2_v2' of experiment 'group1_exp2'.")

      # forced variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
      # forced variations should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
    end

    it 'should bucket normally if user is whitelisted into a forced variation that is not in the datafile' do
      expect(decision_service.get_variation(config, 'test_experiment', 'forced_user_with_invalid_variation')).to eq('111128')
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
      it 'should look up the UserProfile, bucket normally, and save the result if no saved profile is found' do
        expected_user_profile = {
          user_id: 'test_user',
          experiment_bucket_map: {
            '111127' => {
              variation_id: '111128'
            }
          }
        }
        expect(spy_user_profile_service).to receive(:lookup).once.and_return(nil)

        expect(decision_service.get_variation(config, 'test_experiment', 'test_user')).to eq('111128')

        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once
        # bucketing decision should have been saved
        expect(spy_user_profile_service).to have_received(:save).once.with(expected_user_profile)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::INFO, "Saved variation ID 111128 of experiment ID 111127 for user 'test_user'.")
      end

      it 'should look up the UserProfile, bucket normally (using Bucketing ID attribute), and save the result if no saved profile is found' do
        expected_user_profile = {
          user_id: 'test_user',
          experiment_bucket_map: {
            '111127' => {
              variation_id: '111129'
            }
          }
        }
        user_attributes = {
          'browser_type' => 'firefox',
          Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 'pid'
        }
        expect(spy_user_profile_service).to receive(:lookup).once.and_return(nil)

        expect(decision_service.get_variation(config, 'test_experiment', 'test_user', user_attributes)).to eq('111129')

        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once
        # bucketing decision should have been saved
        expect(spy_user_profile_service).to have_received(:save).once.with(expected_user_profile)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::INFO, "Saved variation ID 111129 of experiment ID 111127 for user 'test_user'.")
      end

      it 'should look up the user profile and skip normal bucketing if a profile with a saved decision is found' do
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

        expect(decision_service.get_variation(config, 'test_experiment', 'test_user')).to eq('111129')
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::INFO, "Returning previously activated variation ID 111129 of experiment 'test_experiment' for user 'test_user' from user profile.")

        # saved user profiles should short circuit bucketing
        expect(decision_service.bucketer).not_to have_received(:bucket)
        # saved user profiles should short circuit audience evaluation
        expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
        # the user profile should not be updated if bucketing did not take place
        expect(spy_user_profile_service).not_to have_received(:save)
      end

      it 'should look up the user profile and bucket normally if a profile without a saved decision is found' do
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

        expect(decision_service.get_variation(config, 'test_experiment', 'test_user')).to eq('111128')

        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once

        # user profile should have been updated with bucketing decision
        expected_user_profile = {
          user_id: 'test_user',
          experiment_bucket_map: {
            '111127' => {
              variation_id: '111128'
            },
            '122227' => {
              variation_id: '122228'
            }
          }
        }
        expect(spy_user_profile_service).to have_received(:save).once.with(expected_user_profile)
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

        expect(decision_service.get_variation(config, 'test_experiment', 'test_user')).to eq('111128')

        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once

        # user profile should have been updated with bucketing decision
        expected_user_profile = {
          user_id: 'test_user',
          experiment_bucket_map: {
            '111127' => {
              variation_id: '111128'
            }
          }
        }
        expect(spy_user_profile_service).to have_received(:save).with(expected_user_profile)
      end

      it 'should bucket normally if the user profile service throws an error during lookup' do
        expect(spy_user_profile_service).to receive(:lookup).once.with('test_user').and_throw(:LookupError)

        expect(decision_service.get_variation(config, 'test_experiment', 'test_user')).to eq('111128')

        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::ERROR, "Error while looking up user profile for user ID 'test_user': uncaught throw :LookupError.")
        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once
      end

      it 'should log an error if the user profile service throws an error during save' do
        expect(spy_user_profile_service).to receive(:save).once.and_throw(:SaveError)

        expect(decision_service.get_variation(config, 'test_experiment', 'test_user')).to eq('111128')

        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::ERROR, "Error while saving user profile for user ID 'test_user': uncaught throw :SaveError.")
      end

      describe 'IGNORE_USER_PROFILE_SERVICE decide option' do
        it 'should ignore user profile service if this option is set' do
          allow(spy_user_profile_service).to receive(:lookup)
            .with('test_user').once.and_return(nil)

          expect(decision_service.get_variation(config, 'test_experiment', 'test_user', nil, [Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE])).to eq('111128')

          expect(decision_service.bucketer).to have_received(:bucket)
          expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?)
          expect(spy_user_profile_service).not_to have_received(:lookup)
          expect(spy_user_profile_service).not_to have_received(:save)
        end

        it 'should not ignore user profile service if this option is not set' do
          allow(spy_user_profile_service).to receive(:lookup)
            .with('test_user').once.and_return(nil)

          expect(decision_service.get_variation(config, 'test_experiment', 'test_user')).to eq('111128')

          expect(decision_service.bucketer).to have_received(:bucket)
          expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?)
          expect(spy_user_profile_service).to have_received(:lookup)
          expect(spy_user_profile_service).to have_received(:save)
        end
      end
    end
  end

  describe '#get_variation_for_feature_experiment' do
    user_attributes = {}
    user_id = 'user_1'

    describe 'when the feature flag\'s experiment ids array is empty' do
      it 'should return nil and log a message' do
        feature_flag = config.feature_flag_key_map['empty_feature']
        expect(decision_service.get_variation_for_feature_experiment(config, feature_flag, 'user_1', user_attributes)).to eq(nil)

        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::DEBUG, "The feature flag 'empty_feature' is not used in any experiments.")
      end
    end

    describe 'and the experiment is not in the datafile' do
      it 'should return nil and log a message' do
        feature_flag = config.feature_flag_key_map['boolean_feature'].dup
        # any string that is not an experiment id in the data file
        feature_flag['experimentIds'] = ['1333333337']
        expect(decision_service.get_variation_for_feature_experiment(config, feature_flag, user_id, user_attributes)).to eq(nil)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::DEBUG, "Feature flag experiment with ID '1333333337' is not in the datafile.")
      end
    end

    describe 'when the feature flag is associated with a non-mutex experiment' do
      describe 'and the user is not bucketed into the feature flag\'s experiments' do
        before(:each) do
          multivariate_experiment = config.experiment_key_map['test_experiment_multivariate']

          # make sure the user is not bucketed into the feature experiment
          allow(decision_service).to receive(:get_variation)
            .with(config, multivariate_experiment['key'], 'user_1', user_attributes, [], nil)
            .and_return(nil)
        end

        it 'should return nil and log a message' do
          feature_flag = config.feature_flag_key_map['multi_variate_feature']
          expect(decision_service.get_variation_for_feature_experiment(config, feature_flag, 'user_1', user_attributes, [], nil)).to eq(nil)

          expect(spy_logger).to have_received(:log).once
                                                   .with(Logger::INFO, "The user 'user_1' is not bucketed into any of the experiments on the feature 'multi_variate_feature'.")
        end
      end

      describe 'and the user is bucketed into a variation for the experiment on the feature flag' do
        before(:each) do
          # mock and return the first variation of the `test_experiment_multivariate` experiment, which is attached to the `multi_variate_feature`
          allow(decision_service).to receive(:get_variation).and_return('122231')
        end

        it 'should return the variation' do
          user_attributes = {}
          feature_flag = config.feature_flag_key_map['multi_variate_feature']
          expected_decision = Optimizely::DecisionService::Decision.new(
            config.experiment_key_map['test_experiment_multivariate'],
            config.variation_id_map['test_experiment_multivariate']['122231'],
            Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          )
          expect(decision_service.get_variation_for_feature_experiment(config, feature_flag, 'user_1', user_attributes)).to eq(expected_decision)
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
            .and_return(variation['id'])
        end

        it 'should return the variation the user is bucketed into' do
          feature_flag = config.feature_flag_key_map['mutex_group_feature']
          expect(decision_service.get_variation_for_feature_experiment(config, feature_flag, user_id, user_attributes)).to eq(expected_decision)
        end
      end

      describe 'and the user is not bucketed into any of the mutex experiments' do
        before(:each) do
          mutex_exp = config.experiment_key_map['group1_exp1']
          mutex_exp2 = config.experiment_key_map['group1_exp2']
          allow(decision_service).to receive(:get_variation)
            .with(config, mutex_exp['key'], user_id, user_attributes, [], nil)
            .and_return(nil)
          allow(decision_service).to receive(:get_variation)
            .with(config, mutex_exp2['key'], user_id, user_attributes, [], nil)
            .and_return(nil)
        end

        it 'should return nil and log a message' do
          feature_flag = config.feature_flag_key_map['mutex_group_feature']
          expect(decision_service.get_variation_for_feature_experiment(config, feature_flag, user_id, user_attributes)).to eq(nil)

          expect(spy_logger).to have_received(:log).once
                                                   .with(Logger::INFO, "The user 'user_1' is not bucketed into any of the experiments on the feature 'mutex_group_feature'.")
        end
      end
    end
  end

  describe '#get_variation_for_feature_rollout' do
    user_attributes = {}
    user_id = 'user_1'

    describe 'when the feature flag is not associated with a rollout' do
      it 'should log a message and return nil' do
        feature_flag = config.feature_flag_key_map['boolean_feature']
        expect(decision_service.get_variation_for_feature_rollout(config, feature_flag, user_id, user_attributes)).to eq(nil)

        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::DEBUG, "Feature flag '#{feature_flag['key']}' is not used in a rollout.")
      end
    end

    describe 'when the rollout is not in the datafile' do
      it 'should log a message and return nil' do
        feature_flag = config.feature_flag_key_map['boolean_feature'].dup
        feature_flag['rolloutId'] = 'invalid_rollout_id'
        expect(decision_service.get_variation_for_feature_rollout(config, feature_flag, user_id, user_attributes)).to eq(nil)

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
        expect(decision_service.get_variation_for_feature_rollout(config, feature_flag, user_id, user_attributes)).to eq(nil)
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
          expect(decision_service.get_variation_for_feature_rollout(config, feature_flag, user_id, user_attributes, nil)).to eq(expected_decision)
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

            expect(decision_service.get_variation_for_feature_rollout(config, feature_flag, user_id, user_attributes, nil)).to eq(nil)

            # make sure we only checked the audience for the first rule
            expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?).once
                                                                                           .with(config, rollout['experiments'][0], user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 1)
            expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
              .with(config, rollout['experiments'][1], user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 2)
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

            expect(decision_service.get_variation_for_feature_rollout(config, feature_flag, user_id, user_attributes, nil)).to eq(expected_decision)

            # make sure we only checked the audience for the first rule
            expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?).once
                                                                                           .with(config, rollout['experiments'][0], user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 1)
            expect(Optimizely::Audience).not_to have_received(:user_meets_audience_conditions?)
              .with(config, rollout['experiments'][1], user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 2)
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
          .with(config, everyone_else_experiment, user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 'Everyone Else')
          .and_return(true)
        allow(decision_service.bucketer).to receive(:bucket)
          .with(config, everyone_else_experiment, user_id, user_id)
          .and_return(variation)

        expect(decision_service.get_variation_for_feature_rollout(config, feature_flag, user_id, user_attributes, nil)).to eq(expected_decision)

        # verify we tried to bucket in all targeting rules and the everyone else rule
        expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?)
          .with(config, rollout['experiments'][0], user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 1)
        expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?)
          .with(config, rollout['experiments'][1], user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 2)
        expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?)
          .with(config, rollout['experiments'][2], user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 'Everyone Else')

        # verify log messages
        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' does not meet the audience conditions for targeting rule '1'.")

        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' does not meet the audience conditions for targeting rule '2'.")

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

        expect(decision_service.get_variation_for_feature_rollout(config, feature_flag, user_id, user_attributes)).to eq(nil)

        # verify we tried to bucket in all targeting rules and the everyone else rule
        expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?).once
                                                                                       .with(config, rollout['experiments'][0], user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 1)
        expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?)
          .with(config, rollout['experiments'][1], user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 2)
        expect(Optimizely::Audience).to have_received(:user_meets_audience_conditions?)
          .with(config, rollout['experiments'][2], user_attributes, spy_logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', 'Everyone Else')

        # verify log messages
        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' does not meet the audience conditions for targeting rule '1'.")

        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' does not meet the audience conditions for targeting rule '2'.")

        expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "User '#{user_id}' does not meet the audience conditions for targeting rule 'Everyone Else'.")
      end
    end
  end

  describe '#get_variation_for_feature' do
    user_attributes = {}
    user_id = 'user_1'

    describe 'when the user is bucketed into the feature experiment' do
      it 'should return the bucketed experiment and variation' do
        feature_flag = config.feature_flag_key_map['string_single_variable_feature']
        expected_experiment = config.experiment_id_map[feature_flag['experimentIds'][0]]
        expected_variation = expected_experiment['variations'][0]
        expected_decision = {
          'experiment' => expected_experiment,
          'variation' => expected_variation
        }
        allow(decision_service).to receive(:get_variation_for_feature_experiment).and_return(expected_decision)

        expect(decision_service.get_variation_for_feature(config, feature_flag, user_id, user_attributes)).to eq(expected_decision)
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
          allow(decision_service).to receive(:get_variation_for_feature_experiment).and_return(nil)
          allow(decision_service).to receive(:get_variation_for_feature_rollout).and_return(expected_decision)

          expect(decision_service.get_variation_for_feature(config, feature_flag, user_id, user_attributes)).to eq(expected_decision)
        end
      end

      describe 'and the user is not bucketed into the feature rollout' do
        it 'should log a message and return nil' do
          feature_flag = config.feature_flag_key_map['string_single_variable_feature']
          allow(decision_service).to receive(:get_variation_for_feature_experiment).and_return(nil)
          allow(decision_service).to receive(:get_variation_for_feature_rollout).and_return(nil)

          expect(decision_service.get_variation_for_feature(config, feature_flag, user_id, user_attributes)).to eq(nil)
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
      bucketing_id, = decision_service.send(:get_bucketing_id, 'test_user', user_attributes)
      expect(bucketing_id).to eq('test_user')
      expect(spy_logger).to have_received(:log).once.with(Logger::WARN, 'Bucketing ID attribute is not a string. Defaulted to user ID.')
    end

    it 'should not log any message and return user ID when bucketing ID is nil' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => nil
      }
      bucketing_id, = decision_service.send(:get_bucketing_id, 'test_user', user_attributes)
      expect(bucketing_id).to eq('test_user')
      expect(spy_logger).not_to have_received(:log)
    end

    it 'should not log any message and return given bucketing ID when bucketing ID is a String' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 'i_am_bucketing_id'
      }
      bucketing_id, = decision_service.send(:get_bucketing_id, 'test_user', user_attributes)
      expect(bucketing_id).to eq('i_am_bucketing_id')
      expect(spy_logger).not_to have_received(:log)
    end

    it 'should not log any message and return empty String when bucketing ID is empty String' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => ''
      }
      bucketing_id, = decision_service.send(:get_bucketing_id, 'test_user', user_attributes)
      expect(bucketing_id).to eq('')
      expect(spy_logger).not_to have_received(:log)
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
      expect(decision_service.get_forced_variation(config, valid_experiment[:key], user_id)).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG,
                                                     "User '#{user_id}' is not in the forced variation map.")
    end
    # Experiment key does not exist in the datafile
    it 'should return nil when experiment key is not in datafile' do
      expect(decision_service.get_forced_variation(config, invalid_experiment_key, user_id)).to eq(nil)
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
      variation = decision_service.get_forced_variation(config, valid_experiment[:key], user_id)
      expect(variation['id']).to eq(valid_variation[:id])
      expect(variation['key']).to eq(valid_variation[:key])

      expect(decision_service.set_forced_variation(config, valid_experiment[:key], user_id, valid_variation_2[:key])).to eq(true)
      variation = decision_service.get_forced_variation(config, valid_experiment[:key], user_id)
      expect(variation['id']).to eq(valid_variation_2[:id])
      expect(variation['key']).to eq(valid_variation_2[:key])
    end

    # Set variation on multiple experiments for one user.
    it 'should set and return expected variations when variation is set for multiple experiments for one user' do
      expect(decision_service.set_forced_variation(config, valid_experiment[:key], user_id, valid_variation[:key])).to eq(true)
      variation = decision_service.get_forced_variation(config, valid_experiment[:key], user_id)
      expect(variation['id']).to eq(valid_variation[:id])
      expect(variation['key']).to eq(valid_variation[:key])

      expect(decision_service.set_forced_variation(config, valid_experiment_2[:key], user_id, valid_variation_for_exp_2[:key])).to eq(true)
      variation = decision_service.get_forced_variation(config, valid_experiment_2[:key], user_id)
      expect(variation['id']).to eq(valid_variation_for_exp_2[:id])
      expect(variation['key']).to eq(valid_variation_for_exp_2[:key])
    end

    # Set variations for multiple users.
    it 'should set and return expected variations when variations are set for multiple users' do
      expect(decision_service.set_forced_variation(config, valid_experiment[:key], user_id, valid_variation[:key])).to eq(true)
      variation = decision_service.get_forced_variation(config, valid_experiment[:key], user_id)
      expect(variation['id']).to eq(valid_variation[:id])
      expect(variation['key']).to eq(valid_variation[:key])

      expect(decision_service.set_forced_variation(config, valid_experiment[:key], user_id_2, valid_variation[:key])).to eq(true)
      variation = decision_service.get_forced_variation(config, valid_experiment[:key], user_id_2)
      expect(variation['id']).to eq(valid_variation[:id])
      expect(variation['key']).to eq(valid_variation[:key])
    end
  end
end
