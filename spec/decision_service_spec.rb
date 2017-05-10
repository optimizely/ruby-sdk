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

  describe '#get_forced_variation_id' do
    it 'should return correct variation ID if user ID is in forcedVariations and variation is valid' do
      expect(decision_service.get_forced_variation_id('test_experiment', 'forced_user1')).to eq('111128')
      expect(spy_logger).to have_received(:log)
                              .once.with(Logger::INFO, "User 'forced_user1' is forced in variation 'control'.")

      expect(decision_service.get_forced_variation_id('test_experiment', 'forced_user2')).to eq('111129')
      expect(spy_logger).to have_received(:log)
                              .once.with(Logger::INFO, "User 'forced_user2' is forced in variation 'variation'.")
    end

    it 'should return null if forced variation ID is not in the datafile' do
      expect(decision_service.get_forced_variation_id('test_experiment', 'forced_user_with_invalid_variation')).to be_nil
    end

    it 'should respect forced variations within mutually exclusive grouped experiments' do
      expect(decision_service.get_forced_variation_id('group1_exp2', 'forced_group_user1')).to eq('130004')
      expect(spy_logger).to have_received(:log)
                              .once.with(Logger::INFO, "User 'forced_group_user1' is forced in variation 'g1_e2_v2'.")
    end
  end
end
