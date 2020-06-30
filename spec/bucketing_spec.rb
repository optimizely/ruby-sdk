# frozen_string_literal: true

#
#    Copyright 2016-2017, 2019 Optimizely and contributors
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
require 'optimizely/bucketer'
require 'optimizely/error_handler'
require 'optimizely/logger'

describe Optimizely::Bucketer do
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:bucketer) { Optimizely::Bucketer.new(spy_logger) }

  def get_bucketing_key(bucketing_id, entity_id = nil)
    entity_id ||= 1_886_780_721
    format(Optimizely::Bucketer::BUCKETING_ID_TEMPLATE, bucketing_id: bucketing_id, entity_id: entity_id)
  end

  it 'should return correct variation ID when provided bucket value' do
    expect(bucketer).to receive(:generate_bucket_value).exactly(3).times.and_return(50, 5050, 50_000)

    experiment = config.get_experiment_from_key('test_experiment')

    # Variation 1
    expected_variation_1 = config.get_variation_from_id('test_experiment', '111128')
    expect(bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')).to eq(expected_variation_1)

    # Variation 2
    expected_variation_2 = config.get_variation_from_id('test_experiment', '111129')
    expect(bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')).to eq(expected_variation_2)

    # No matching variation
    expect(bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')).to be_nil
  end

  it 'should test the output of generate_bucket_value for different inputs' do
    expect(bucketer.send(:generate_bucket_value, get_bucketing_key('ppid1'))).to eq(5254)
    expect(bucketer.send(:generate_bucket_value, get_bucketing_key('ppid2'))).to eq(4299)
    expect(bucketer.send(:generate_bucket_value, get_bucketing_key('ppid2', 1_886_780_722))).to eq(2434)
    expect(bucketer.send(:generate_bucket_value, get_bucketing_key('ppid3'))).to eq(5439)
    expect(bucketer.send(:generate_bucket_value, get_bucketing_key(
                                                   'a very very very very very very very very very very very very '\
                                                   'very very very long ppd string'
                                                 ))).to eq(6128)
  end

  it 'should return the proper variation for a user in a mutually exclusive grouped experiment' do
    expect(bucketer).to receive(:generate_bucket_value).twice.and_return(3000)

    experiment = config.get_experiment_from_key('group1_exp1')
    expected_variation = config.get_variation_from_id('group1_exp1', '130001')
    expect(bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')).to eq(expected_variation)
    expect(spy_logger).to have_received(:log).exactly(3).times
    expect(spy_logger).to have_received(:log).twice
                                             .with(Logger::DEBUG, "Assigned bucket 3000 to user 'test_user' with bucketing ID: 'bucket_id_ignored'.")
    expect(spy_logger).to have_received(:log)
      .with(Logger::INFO, "User 'test_user' is in experiment 'group1_exp1' of group 101.")
  end

  it 'should return nil when user is bucketed into a different mutually exclusive grouped experiment than specified' do
    expect(bucketer).to receive(:generate_bucket_value).once.and_return(3000)

    experiment = config.get_experiment_from_key('group1_exp2')
    expect(bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')).to be_nil
    expect(spy_logger).to have_received(:log)
      .with(Logger::DEBUG, "Assigned bucket 3000 to user 'test_user' with bucketing ID: 'bucket_id_ignored'.")
    expect(spy_logger).to have_received(:log)
      .with(Logger::INFO, "User 'test_user' is not in experiment 'group1_exp2' of group 101.")
  end

  it 'should return nil when user is not bucketed into any bucket' do
    expect(bucketer).to receive(:find_bucket).once.and_return(nil)

    experiment = config.get_experiment_from_key('group1_exp2')
    expect(bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')).to be_nil
    expect(spy_logger).to have_received(:log)
      .with(Logger::INFO, "User 'test_user' is in no experiment.")
  end

  it 'should return the proper variation for a user in an overlapping grouped experiment' do
    expect(bucketer).to receive(:generate_bucket_value).once.and_return(3000)

    experiment = config.get_experiment_from_key('group2_exp1')
    expected_variation = config.get_variation_from_id('group2_exp1', '144443')
    expect(bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')).to eq(expected_variation)
    expect(spy_logger).to have_received(:log).once
    expect(spy_logger).to have_received(:log)
      .with(Logger::DEBUG, "Assigned bucket 3000 to user 'test_user' with bucketing ID: 'bucket_id_ignored'.")
  end

  it 'should return nil when a user is in no variation of an overlapping grouped experiment' do
    expect(bucketer).to receive(:generate_bucket_value).and_return(50_000)

    experiment = config.get_experiment_from_key('group2_exp1')
    expect(bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')).to be_nil
    expect(spy_logger).to have_received(:log).once
    expect(spy_logger).to have_received(:log)
      .with(Logger::DEBUG, "Assigned bucket 50000 to user 'test_user' with bucketing ID: 'bucket_id_ignored'.")
  end

  it 'should call generate_bucket_value with the proper arguments during variation bucketing' do
    expected_bucketing_id = get_bucketing_key('bucket_id_string', '111127')
    expect(bucketer).to receive(:generate_bucket_value).once.with(expected_bucketing_id).and_call_original

    experiment = config.get_experiment_from_key('test_experiment')
    bucketer.bucket(config, experiment, 'bucket_id_string', 'test_user')
  end

  it 'should call generate_bucket_value with the proper arguments during grouped experiment bucketing' do
    expected_bucketing_id = get_bucketing_key('ppid8', '101')
    expect(bucketer).to receive(:generate_bucket_value).once.with(expected_bucketing_id).and_call_original

    experiment = config.get_experiment_from_key('group1_exp1')
    bucketer.bucket(config, experiment, 'ppid8', 'test_user')

    expect(spy_logger).to have_received(:log)
      .with(Logger::INFO, "User 'test_user' is not in experiment '#{experiment['key']}' of "\
                          "group #{experiment['groupId']}.")
  end

  it 'should return nil when user is in an empty traffic allocation range due to sticky bucketing' do
    expect(bucketer).to receive(:find_bucket).once.and_return('')
    experiment = config.get_experiment_from_key('test_experiment')
    expect(bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')).to be_nil
    expect(spy_logger).to have_received(:log)
      .with(Logger::DEBUG, 'Bucketed into an empty traffic range. Returning nil.')
  end

  describe 'Bucketing with Bucketing Id' do
    # Bucketing with bucketing ID
    # Make sure that the bucketing ID is used for the bucketing and not the user ID
    it 'should bucket to a variation different than the one expected with the userId' do
      experiment = config.get_experiment_from_key('test_experiment')

      # Bucketing with user id as bucketing id - 'test_user111127' produces bucket value < 5000 thus buckets to control
      expected_variation = config.get_variation_from_id('test_experiment', '111128')
      expect(bucketer.bucket(config, experiment, 'test_user', 'test_user')).to be(expected_variation)

      # Bucketing with bucketing id - 'any_string789111127' produces bucket value btw 5000 to 10,000
      # thus buckets to variation
      expected_variation = config.get_variation_from_id('test_experiment', '111129')
      expect(bucketer.bucket(config, experiment, 'any_string789', 'test_user')).to be(expected_variation)
    end

    # Bucketing with invalid experiment key and bucketing ID
    it 'should return nil with invalid experiment and bucketing ID' do
      expect(bucketer.bucket(config, config.get_experiment_from_key('invalid_experiment'), 'some_id', 'test_user')).to be(nil)
    end

    # Bucketing with grouped experiments and bucketing ID
    # Make sure that the bucketing ID is used for the bucketing and not the user ID
    it 'should bucket to a variation different than the one expected with the userId in grouped experiments' do
      experiment = config.get_experiment_from_key('group1_exp1')

      expected_variation = nil
      expect(bucketer.bucket(config, experiment, 'test_user', 'test_user')).to be(expected_variation)

      expected_variation = config.get_variation_from_id('group1_exp1', '130002')
      expect(bucketer.bucket(config, experiment, '123456789', 'test_user')).to be(expected_variation)
    end
  end

  describe 'logging' do
    it 'should log the results of bucketing a user into variation 1' do
      expect(bucketer).to receive(:generate_bucket_value).and_return(50)

      experiment = config.get_experiment_from_key('test_experiment')
      bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')
      expect(spy_logger).to have_received(:log).once
      expect(spy_logger).to have_received(:log)
        .with(Logger::DEBUG, "Assigned bucket 50 to user 'test_user' with bucketing ID: 'bucket_id_ignored'.")
    end

    it 'should log the results of bucketing a user into variation 2' do
      expect(bucketer).to receive(:generate_bucket_value).and_return(5050)

      experiment = config.get_experiment_from_key('test_experiment')
      bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')
      expect(spy_logger).to have_received(:log).once
      expect(spy_logger).to have_received(:log)
        .with(Logger::DEBUG, "Assigned bucket 5050 to user 'test_user' with bucketing ID: 'bucket_id_ignored'.")
    end

    it 'should log the results of bucketing a user into no variation' do
      expect(bucketer).to receive(:generate_bucket_value).and_return(50_000)

      experiment = config.get_experiment_from_key('test_experiment')
      bucketer.bucket(config, experiment, 'bucket_id_ignored', 'test_user')
      expect(spy_logger).to have_received(:log).once
      expect(spy_logger).to have_received(:log)
        .with(Logger::DEBUG, "Assigned bucket 50000 to user 'test_user' with bucketing ID: 'bucket_id_ignored'.")
    end
  end
end
