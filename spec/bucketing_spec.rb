#
#    Copyright 2016, Optimizely and contributors
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
require 'optimizely/bucketer'
require 'optimizely/error_handler'
require 'optimizely/logger'

describe Optimizely::Bucketer do
  let(:config_body) { OptimizelySpec::V1_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::V1_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:bucketer) { Optimizely::Bucketer.new(config) }

  def get_bucketing_id(user_id, entity_id=nil)
    entity_id = entity_id || 1886780721
    sprintf(Optimizely::Bucketer::BUCKETING_ID_TEMPLATE, {user_id: user_id, entity_id: entity_id})
  end

  it 'should return correct variation ID when provided bucket value' do
    expect(bucketer).to receive(:generate_bucket_value).exactly(3).times.and_return(50, 5050, 50000)

    # Variation 1
    expect(bucketer.bucket('test_experiment', 'test_user')).to eq('111128')

    # Variation 2
    expect(bucketer.bucket('test_experiment', 'test_user')).to eq('111129')

    # No matching variation
    expect(bucketer.bucket('test_experiment', 'test_user')).to be_nil
  end

  it 'should test the output of generate_bucket_value for different inputs' do
    expect(bucketer.send(:generate_bucket_value, get_bucketing_id('ppid1'))).to eq(5254)
    expect(bucketer.send(:generate_bucket_value, get_bucketing_id('ppid2'))).to eq(4299)
    expect(bucketer.send(:generate_bucket_value, get_bucketing_id('ppid2', 1886780722))).to eq(2434)
    expect(bucketer.send(:generate_bucket_value, get_bucketing_id('ppid3'))).to eq(5439)
    expect(bucketer.send(:generate_bucket_value, get_bucketing_id(
      'a very very very very very very very very very very very very very very very long ppd string'))).to eq(6128)
  end

  it 'should return correct variation ID if user ID is in forcedVariations and variation is valid' do
    expect(bucketer.bucket('test_experiment', 'forced_user1')).to eq('111128')
    expect(spy_logger).to have_received(:log)
                      .once.with(Logger::INFO, "User 'forced_user1' is forced in variation 'control'.")

    expect(bucketer.bucket('test_experiment', 'forced_user2')).to eq('111129')
    expect(spy_logger).to have_received(:log)
                      .once.with(Logger::INFO, "User 'forced_user2' is forced in variation 'variation'.")
  end

  it 'should return null if forced variation ID is not in the datafile' do
    expect(bucketer.bucket('test_experiment', 'forced_user_with_invalid_variation')).to be_nil
  end

  it 'should return the proper variation for a user in a mutually exclusive grouped experiment' do
    expect(bucketer).to receive(:generate_bucket_value).twice.and_return(3000)

    expect(bucketer.bucket('group1_exp1', 'test_user')).to eq('130001')
    expect(spy_logger).to have_received(:log).exactly(4).times
    expect(spy_logger).to have_received(:log)
                      .with(Logger::DEBUG, "Assigned experiment bucket 3000 to user 'test_user'.")
    expect(spy_logger).to have_received(:log)
                      .with(Logger::INFO, "User 'test_user' is in experiment 'group1_exp1' of group 101.")
    expect(spy_logger).to have_received(:log)
                      .with(Logger::DEBUG, "Assigned variation bucket 3000 to user 'test_user'.")
    expect(spy_logger).to have_received(:log)
      .with(Logger::INFO, "User 'test_user' is in variation 'g1_e1_v1' of experiment 'group1_exp1'.")
  end

  it 'should return nil when user is bucketed into a different mutually exclusive grouped experiment than specified' do
    expect(bucketer).to receive(:generate_bucket_value).once.and_return(3000)

    expect(bucketer.bucket('group1_exp2', 'test_user')).to be_nil
    expect(spy_logger).to have_received(:log)
                      .with(Logger::DEBUG, "Assigned experiment bucket 3000 to user 'test_user'.")
    expect(spy_logger).to have_received(:log)
                      .with(Logger::INFO, "User 'test_user' is not in experiment 'group1_exp2' of group 101.")
  end

  it 'should respect forced variations within mutually exclusive grouped experiments' do
    expect(bucketer).not_to receive(:generate_bucket_value)

    expect(bucketer.bucket('group1_exp2', 'forced_group_user1')).to eq('130004')
    expect(spy_logger).to have_received(:log)
                      .once.with(Logger::INFO, "User 'forced_group_user1' is forced in variation 'g1_e2_v2'.")
  end

  it 'should return the proper variation for a user in an overlapping grouped experiment' do
    expect(bucketer).to receive(:generate_bucket_value).once.and_return(3000)

    expect(bucketer.bucket('group2_exp1', 'test_user')).to eq('144443')
    expect(spy_logger).to have_received(:log).twice
    expect(spy_logger).to have_received(:log)
      .with(Logger::DEBUG, "Assigned variation bucket 3000 to user 'test_user'.")
    expect(spy_logger).to have_received(:log)
      .with(Logger::INFO, "User 'test_user' is in variation 'g2_e1_v1' of experiment 'group2_exp1'.")
  end

  it 'should return nil when a user is in no variation of an overlapping grouped experiment' do
    expect(bucketer).to receive(:generate_bucket_value).and_return(50_000)

    expect(bucketer.bucket('group2_exp1', 'test_user')).to be_nil
    expect(spy_logger).to have_received(:log).twice
    expect(spy_logger).to have_received(:log)
      .with(Logger::DEBUG, "Assigned variation bucket 50000 to user 'test_user'.")
    expect(spy_logger).to have_received(:log)
      .with(Logger::INFO, "User 'test_user' is in no variation.")
  end

  it 'should call generate_bucket_value with the proper arguments during variation bucketing' do
    expected_bucketing_id = get_bucketing_id('test_user', '111127')
    expect(bucketer).to receive(:generate_bucket_value).once.with(expected_bucketing_id).and_call_original
    bucketer.bucket('test_experiment', 'test_user')
  end

  it 'should call generate_bucket_value with the proper arguments during grouped experiment bucketing' do
    expected_bucketing_id = get_bucketing_id('test_user', '101')
    expect(bucketer).to receive(:generate_bucket_value).once.with(expected_bucketing_id).and_call_original
    bucketer.bucket('group1_exp1', 'test_user')
  end

  describe 'logging' do
    it 'should log the results of bucketing a user into variation 1' do
      expect(bucketer).to receive(:generate_bucket_value).and_return(50)

      bucketer.bucket('test_experiment', 'test_user')
      expect(spy_logger).to have_received(:log).twice
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "Assigned variation bucket 50 to user 'test_user'.")
      expect(spy_logger).to have_received(:log).with(
        Logger::INFO,
        "User 'test_user' is in variation 'control' of experiment 'test_experiment'."
      )
    end

    it 'should log the results of bucketing a user into variation 2' do
      expect(bucketer).to receive(:generate_bucket_value).and_return(5050)

      bucketer.bucket('test_experiment', 'test_user')
      expect(spy_logger).to have_received(:log).twice
      expect(spy_logger).to have_received(:log)
                        .with(Logger::DEBUG, "Assigned variation bucket 5050 to user 'test_user'.")
      expect(spy_logger).to have_received(:log).with(
        Logger::INFO,
        "User 'test_user' is in variation 'variation' of experiment 'test_experiment'."
      )
    end

    it 'should log the results of bucketing a user into no variation' do
      expect(bucketer).to receive(:generate_bucket_value).and_return(50000)

      bucketer.bucket('test_experiment', 'test_user')
      expect(spy_logger).to have_received(:log).twice
      expect(spy_logger).to have_received(:log)
                        .with(Logger::DEBUG, "Assigned variation bucket 50000 to user 'test_user'.")
      expect(spy_logger).to have_received(:log)
                        .with(Logger::INFO, "User 'test_user' is in no variation.")
    end
  end
end
