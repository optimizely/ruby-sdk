#
#    Copyright 2017, Optimizely and contributors
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
require 'optimizely/decision_service'
require 'optimizely/error_handler'
require 'optimizely/logger'

describe Optimizely::DecisionService do
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:spy_user_profile_service) { spy('user_profile_service') }
  let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:decision_service) { Optimizely::DecisionService.new(config, spy_user_profile_service) }

  describe '#get_variation' do
    before(:example) do
      # stub out bucketer and audience evaluator so we can make sure they are / aren't called
      allow(decision_service.bucketer).to receive(:bucket).and_call_original
      allow(decision_service).to receive(:get_forced_variation_id).and_call_original
      allow(Optimizely::Audience).to receive(:user_in_experiment?).and_call_original

      # by default, spy user profile service should no-op. we override this behavior in specific tests
      allow(spy_user_profile_service).to receive(:lookup).and_return(nil)
    end

    it 'should return the correct variation ID for a given user ID and key of a running experiment' do
      expect(decision_service.get_variation('test_experiment', 'test_user')).to eq('111128')

      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::INFO,"User 'test_user' is in variation 'control' of experiment 'test_experiment'.")
      expect(decision_service).to have_received(:get_forced_variation_id).once
      expect(decision_service.bucketer).to have_received(:bucket).once
    end

    it 'should return correct variation ID if user ID is in forcedVariations and variation is valid' do
      expect(decision_service.get_variation('test_experiment', 'forced_user1')).to eq('111128')
      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::INFO, "User 'forced_user1' is whitelisted into variation 'control' of experiment 'test_experiment'.")

      expect(decision_service.get_variation('test_experiment', 'forced_user2')).to eq('111129')
      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::INFO, "User 'forced_user2' is whitelisted into variation 'variation' of experiment 'test_experiment'.")

      # forced variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
      # forced variations should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_in_experiment?)
    end

    it 'should return the correct variation ID for a user in a forced variation (even when audience conditions do not match)' do
      user_attributes = {'browser_type' => 'wrong_browser'}
      expect(decision_service.get_variation('test_experiment_with_audience', 'forced_audience_user', user_attributes)).to eq('122229')
      expect(spy_logger).to have_received(:log)
                            .once.with(
                              Logger::INFO,
                              "User 'forced_audience_user' is whitelisted into variation 'variation_with_audience' of experiment 'test_experiment_with_audience'."
                            )

      # forced variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
      # forced variations should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_in_experiment?)
    end

    it 'should return nil if the experiment key is invalid' do
      expect(decision_service.get_variation('totally_invalid_experiment', 'test_user', {})).to eq(nil)

      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::ERROR,"Experiment key 'totally_invalid_experiment' is not in datafile.")
    end

    it 'should return nil if the user does not meet the audience conditions for a given experiment' do
      user_attributes = {'browser_type' => 'chrome'}
      expect(decision_service.get_variation('test_experiment_with_audience', 'test_user', user_attributes)).to eq(nil)
      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::INFO,"User 'test_user' does not meet the conditions to be in experiment 'test_experiment_with_audience'.")

      # should have checked forced variations
      expect(decision_service).to have_received(:get_forced_variation_id).once
      # wrong audience conditions should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
    end

    it 'should return nil if the given experiment is not running' do
      expect(decision_service.get_variation('test_experiment_not_started', 'test_user')).to eq(nil)
      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::INFO,"Experiment 'test_experiment_not_started' is not running.")

      # non-running experiments should short circuit whitelisting
      expect(decision_service).not_to have_received(:get_forced_variation_id)
      # non-running experiments should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_in_experiment?)
      # non-running experiments should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
    end

    it 'should respect forced variations within mutually exclusive grouped experiments' do
      expect(decision_service.get_variation('group1_exp2', 'forced_group_user1')).to eq('130004')
      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::INFO, "User 'forced_group_user1' is whitelisted into variation 'g1_e2_v2' of experiment 'group1_exp2'.")

      # forced variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
      # forced variations should short circuit audience evaluation
      expect(Optimizely::Audience).not_to have_received(:user_in_experiment?)
    end

    it 'should bucket normally if user is whitelisted into a forced variation that is not in the datafile' do
      expect(decision_service.get_variation('test_experiment', 'forced_user_with_invalid_variation')).to eq('111128')
      expect(spy_logger).to have_received(:log)
                            .once.with(
                              Logger::INFO,
                              "User 'forced_user_with_invalid_variation' is whitelisted into variation 'invalid_variation', which is not in the datafile."
                            )
      # bucketing should have occured
      experiment = config.get_experiment_from_key('test_experiment')
      expect(decision_service.bucketer).to have_received(:bucket).once.with(experiment, 'forced_user_with_invalid_variation')
    end

    describe 'when a UserProfile service is provided' do
      it 'should look up the UserProfile, bucket normally, and save the result if no saved profile is found' do
        expected_user_profile = {
          :user_id => 'test_user',
          :experiment_bucket_map => {
            '111127' => {
              :variation_id => '111128'
            }
          }
        }
        expect(spy_user_profile_service).to receive(:lookup).once.and_return(nil)

        expect(decision_service.get_variation('test_experiment', 'test_user')).to eq('111128')

        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once
        # bucketing decision should have been saved
        expect(spy_user_profile_service).to have_received(:save).once.with(expected_user_profile)
        expect(spy_logger).to have_received(:log).once
                          .with(Logger::INFO, "Saved variation ID 111128 of experiment ID 111127 for user 'test_user'.")
      end

      it 'should look up the user profile and skip normal bucketing if a profile with a saved decision is found' do
        saved_user_profile = {
          :user_id => 'test_user',
          :experiment_bucket_map => {
            '111127' => {
              :variation_id => '111129'
            }
          }
        }
        expect(spy_user_profile_service).to receive(:lookup)
                                        .with('test_user').once.and_return(saved_user_profile)

        expect(decision_service.get_variation('test_experiment', 'test_user')).to eq('111129')
        expect(spy_logger).to have_received(:log).once
                          .with(Logger::INFO, "Returning previously activated variation ID 111129 of experiment 'test_experiment' for user 'test_user' from user profile.")

        # saved user profiles should short circuit bucketing
        expect(decision_service.bucketer).not_to have_received(:bucket)
        # saved user profiles should short circuit audience evaluation
        expect(Optimizely::Audience).not_to have_received(:user_in_experiment?)
        # the user profile should not be updated if bucketing did not take place
        expect(spy_user_profile_service).not_to have_received(:save)
      end

      it 'should look up the user profile and bucket normally if a profile without a saved decision is found' do
        saved_user_profile = {
          :user_id => 'test_user',
          :experiment_bucket_map => {
            # saved decision, but not for this experiment
            '122227' => {
              :variation_id => '122228'
            }
          }
        }
        expect(spy_user_profile_service).to receive(:lookup)
                                        .once.with('test_user').and_return(saved_user_profile)

        expect(decision_service.get_variation('test_experiment', 'test_user')).to eq('111128')

        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once

        # user profile should have been updated with bucketing decision
        expected_user_profile = {
          :user_id => 'test_user',
          :experiment_bucket_map => {
            '111127' => {
              :variation_id => '111128'
            },
            '122227' => {
              :variation_id => '122228'
            }
          }
        }
        expect(spy_user_profile_service).to have_received(:save).once.with(expected_user_profile)
      end

      it 'should bucket normally if the user profile contains a variation ID not in the datafile' do
        saved_user_profile = {
          :user_id => 'test_user',
          :experiment_bucket_map => {
            # saved decision, but with invalid variation ID
            '111127' => {
              :variation_id => '111111'
            }
          }
        }
        expect(spy_user_profile_service).to receive(:lookup)
                                        .once.with('test_user').and_return(saved_user_profile)

        expect(decision_service.get_variation('test_experiment', 'test_user')).to eq('111128')

        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once

        # user profile should have been updated with bucketing decision
        expected_user_profile = {
          :user_id => 'test_user',
          :experiment_bucket_map => {
            '111127' => {
              :variation_id => '111128'
            }
          }
        }
        expect(spy_user_profile_service).to have_received(:save).with(expected_user_profile)
      end

      it 'should bucket normally if the user profile service throws an error during lookup' do
        expect(spy_user_profile_service).to receive(:lookup).once.with('test_user').and_throw(:LookupError)

        expect(decision_service.get_variation('test_experiment', 'test_user')).to eq('111128')

        expect(spy_logger).to have_received(:log).once
                          .with(Logger::ERROR, "Error while looking up user profile for user ID 'test_user': uncaught throw :LookupError.")
        # bucketing should have occurred
        expect(decision_service.bucketer).to have_received(:bucket).once
      end

      it 'should log an error if the user profile service throws an error during save' do
        expect(spy_user_profile_service).to receive(:save).once.and_throw(:SaveError)

        expect(decision_service.get_variation('test_experiment', 'test_user')).to eq('111128')

        expect(spy_logger).to have_received(:log).once
                          .with(Logger::ERROR, "Error while saving user profile for user ID 'test_user': uncaught throw :SaveError.")
      end
    end
  end

  describe '#get_variation_for_feature' do
    user_attributes = {}
    user_id = 'user_1'

    describe 'when the feature flag\'s experiment ids array is empty' do
      it 'should return nil and log a message' do
        user_attributes = {}
        feature_flag = config.feature_flag_key_map['double_single_variable_feature']
        expect(decision_service.get_variation_for_feature(feature_flag, 'user_1', user_attributes)).to eq(nil)

        expect(spy_logger).to have_received(:log).once
                          .with(Logger::DEBUG, "The feature flag 'double_single_variable_feature' is not used in any experiments.")
      end
    end

    describe 'when the feature flag is associated with a non-mutex experiment' do
      describe 'and the experiment is not in the datafile' do
        it 'should return nil and log a message' do
          feature_flag = config.feature_flag_key_map['boolean_feature'].dup
          feature_flag['experimentIds'] = ['1333333337'] # totally invalid exp id
          expect(decision_service.get_variation_for_feature(feature_flag, user_id, user_attributes)).to eq(nil)

          expect(spy_logger).to have_received(:log).once
                            .with(Logger::DEBUG, "Feature flag experiment with ID '1333333337' is not in the datafile.")
        end
      end

      describe 'and the user is not bucketed into the feature flag\'s experiments' do
        before(:each) do
          multivariate_experiment = config.experiment_key_map['test_experiment_multivariate']

          # make sure the user is not bucketed into the feature experiment
          allow(decision_service).to receive(:get_variation)
                                 .with(multivariate_experiment['key'], 'user_1', user_attributes)
                                 .and_return(nil)
        end
        it 'should return nil and log a message' do
          feature_flag = config.feature_flag_key_map['multi_variate_feature']
          expect(decision_service.get_variation_for_feature(feature_flag, 'user_1', user_attributes)).to eq(nil)

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
          expected_decision = {
            'experiment' => config.experiment_key_map['test_experiment_multivariate'],
            'variation' => config.variation_id_map['test_experiment_multivariate']['122231']
          }
          expect(decision_service.get_variation_for_feature(feature_flag, 'user_1', user_attributes)).to eq(expected_decision)

          expect(spy_logger).to have_received(:log).once
                            .with(Logger::INFO, "The user 'user_1' is bucketed into experiment 'test_experiment_multivariate' of feature 'multi_variate_feature'.")
        end
      end
    end

    describe 'when the feature flag is associated with a mutex experiment' do
      mutex_exp = nil
      expected_decision = nil
      describe 'and the user is bucketed into one of the experiments' do
        before(:each) do
          group_1 = config.group_key_map['101']
          mutex_exp = config.experiment_key_map['group1_exp1']
          expected_variation = mutex_exp['variations'][0]
          expected_decision = {
            'experiment' => mutex_exp,
            'variation' => expected_variation
          }
          allow(decision_service.bucketer).to receive(:find_bucket)
                                          .with(user_id, group_1['id'], group_1['trafficAllocation'])
                                          .and_return(mutex_exp['id'])

          allow(decision_service).to receive(:get_variation)
                                 .and_return(expected_variation['id'])
        end

        it 'should return the variation the user is bucketed into' do
          feature_flag = config.feature_flag_key_map['boolean_feature']
          expect(decision_service.get_variation_for_feature(feature_flag, user_id, user_attributes)).to eq(expected_decision)

          expect(spy_logger).to have_received(:log).once
                            .with(Logger::INFO, "The user 'user_1' is bucketed into experiment 'group1_exp1' of feature 'boolean_feature'.")
        end
      end

      describe 'and the user is not bucketed into any of the mutex experiments' do
        before(:each) do
          group_1 = config.group_key_map['101']
          mutex_exp = config.experiment_key_map['group1_exp1']
          expected_variation = mutex_exp['variations'][0]
          allow(decision_service.bucketer).to receive(:find_bucket)
                                          .with(user_id, group_1['id'], group_1['trafficAllocation'])
                                          .and_return(nil)
        end

        it 'should return nil and log a message' do
          feature_flag = config.feature_flag_key_map['boolean_feature']
          expect(decision_service.get_variation_for_feature(feature_flag, user_id, user_attributes)).to eq(nil)

          expect(spy_logger).to have_received(:log).once
                            .with(Logger::INFO, "The user 'user_1' is not bucketed into any of the experiments on the feature 'boolean_feature'.")
        end
      end
    end
  end
end
