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
  let(:config_body) { OptimizelySpec::V2_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::V2_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:decision_service) { Optimizely::DecisionService.new(config) }

  describe '#get_variation' do
    before(:example) do
      # stub out bucketer.bucket so we can make sure it is / isn't called
      allow(decision_service.bucketer).to receive(:bucket).and_call_original
    end

    it 'should return the correct variation ID for a given user ID and key of a running experiment' do
      expect(decision_service.get_variation('test_experiment', 'test_user')).to eq('111128')

      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::INFO,"User 'test_user' is in variation 'control' of experiment 'test_experiment'.")
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
    end

    it 'should return nil if the user does not meet the audience conditions for a given experiment' do
      user_attributes = {'browser_type' => 'chrome'}
      expect(decision_service.get_variation('test_experiment_with_audience', 'test_user', user_attributes)).to eq(nil)
      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::INFO,"User 'test_user' does not meet the conditions to be in experiment 'test_experiment_with_audience'.")

      # wrong audience conditions should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
    end

    it 'should return nil if the given experiment is not running' do
      expect(decision_service.get_variation('test_experiment_not_started', 'test_user')).to eq(nil)
      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::INFO,"Experiment 'test_experiment_not_started' is not running.")

      # non-running experiments should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
    end

    it 'should respect forced variations within mutually exclusive grouped experiments' do
      expect(decision_service.get_variation('group1_exp2', 'forced_group_user1')).to eq('130004')
      expect(spy_logger).to have_received(:log)
                            .once.with(Logger::INFO, "User 'forced_group_user1' is whitelisted into variation 'g1_e2_v2' of experiment 'group1_exp2'.")

      # forced variations should short circuit bucketing
      expect(decision_service.bucketer).not_to have_received(:bucket)
    end

    it 'should bucket normally if user is whitelisted into a forced variation that is not in the datafile' do
      expect(decision_service.get_variation('test_experiment', 'forced_user_with_invalid_variation')).to eq('111128')
      expect(spy_logger).to have_received(:log)
                            .once.with(
                              Logger::INFO,
                              "User 'forced_user_with_invalid_variation' is whitelisted into variation 'invalid_variation', which is not in the datafile."
                            )
      # bucketing should have occured
      expect(decision_service.bucketer).to have_received(:bucket).once.with('test_experiment', 'forced_user_with_invalid_variation')
    end
  end
end
