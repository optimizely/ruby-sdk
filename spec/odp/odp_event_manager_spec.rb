# frozen_string_literal: true

# Copyright 2022, Optimizely
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'spec_helper'
require 'optimizely/odp/odp_event_manager'
require 'optimizely/odp/odp_event'
require 'optimizely/odp/lru_cache'
require 'optimizely/odp/odp_config'
require 'optimizely/odp/odp_events_api_manager'
require 'optimizely/logger'
require 'optimizely/helpers/validator'

describe Optimizely::OdpEventManager do
  let(:spy_logger) { spy('logger') }
  let(:api_host) { 'https://test-host' }
  let(:user_key) { 'fs_user_id' }
  let(:user_value) { 'test-user-value' }
  let(:api_key) { 'test-api-key' }
  let(:segments_to_check) { %w[a b c] }
  let(:odp_config) { Optimizely::OdpConfig.new(api_key, api_host) }
  let(:test_uuid) { SecureRandom.uuid }
  let(:version) { Optimizely::VERSION }
  let(:events) do
    [
      {type: 't1', action: 'a1', identifiers: {'id-key-1': 'id-value-1'}, data: {'key-1': 'value1', "key-2": 2, "key-3": 3.0, "key-4": nil, 'key-5': true, 'key-6': false}},
      {type: 't2', action: 'a2', identifiers: {'id-key-2': 'id-value-2'}, data: {'key-2': 'value2'}}
    ]
  end
  let(:processed_events) do
    [
      {
        type: 't1',
        action: 'a1',
        identifiers: {'id-key-1': 'id-value-1'},
        data: {
          idempotence_id: test_uuid,
          data_source_type: 'sdk',
          data_source: 'ruby-sdk',
          data_source_version: version,
          'key-1': 'value1',
          "key-2": 2,
          "key-3": 3.0,
          "key-4": nil,
          "key-5": true,
          "key-6": false
        }
      },
      {
        type: 't2',
        action: 'a2',
        identifiers: {'id-key-2': 'id-value-2'},
        data: {
          idempotence_id: test_uuid,
          data_source_type: 'sdk',
          data_source: 'ruby-sdk',
          data_source_version: version,
          'key-2': 'value2'
        }
      }
    ]
  end
  let(:odp_events) do
    [
      Optimizely::OdpEvent.new(**events[0]),
      Optimizely::OdpEvent.new(**events[1])
    ]
  end

  describe 'OdpEvent#initialize' do
    it 'should return proper OdpEvent' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event = events[0]
      expect(Optimizely::Helpers::Validator.odp_data_types_valid?(event[:data])).to be true

      odp_event = Optimizely::OdpEvent.new(**event)
      expect(odp_event.to_json).to be == processed_events[0].to_json
    end

    it 'should fail with invalid event' do
      event = events[0]
      event[:data]['invalid-item'] = {}
      expect(Optimizely::Helpers::Validator.odp_data_types_valid?(event[:data])).to be false
    end
  end

  describe '#initialize' do
    it 'should return OdpEventManager instance' do
      config = Optimizely::OdpConfig.new

      api_manager = Optimizely::OdpEventsApiManager.new
      event_manager = Optimizely::OdpEventManager.new(api_manager: api_manager, logger: spy_logger)
      event_manager.start!(config)

      expect(event_manager.odp_config).to be config
      expect(event_manager.api_manager).to be api_manager
      expect(event_manager.logger).to be spy_logger
      event_manager.stop!

      event_manager = Optimizely::OdpEventManager.new
      expect(event_manager.logger).to be_a Optimizely::NoOpLogger
      expect(event_manager.api_manager).to be_a Optimizely::OdpEventsApiManager
    end
  end

  describe '#event processing' do
    it 'should process events successfully' do
      stub_request(:post, "#{api_host}/v3/events")
        .to_return(status: 200)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      event_manager.start!(odp_config)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      event_manager.stop!
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'ODP event queue: flushing batch size 2.')
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'ODP event queue: received shutdown signal.')
      expect(event_manager.running?).to be false
    end

    it 'should flush at batch size' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      allow(event_manager.api_manager).to receive(:send_odp_events).and_return(false)
      event_manager.start!(odp_config)

      event_manager.instance_variable_set('@batch_size', 2)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'ODP event queue: flushing on batch size.')
      event_manager.stop!
    end

    it 'should flush multiple batches' do
      batch_count = 4

      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      allow(event_manager.api_manager).to receive(:send_odp_events).exactly(batch_count).times.and_return(false)
      event_manager.start!(odp_config)

      event_manager.instance_variable_set('@batch_size', 2)

      batch_count.times do
        event_manager.send_event(**events[0])
        event_manager.send_event(**events[1])
      end
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).exactly(batch_count).times.with(Logger::DEBUG, 'ODP event queue: flushing on batch size.')
      expect(spy_logger).to have_received(:log).exactly(batch_count).times.with(Logger::DEBUG, 'ODP event queue: flushing batch size 2.')

      event_manager.stop!
    end

    it 'should process backlog successfully' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      event_manager.odp_config = odp_config

      event_manager.instance_variable_set('@batch_size', 2)
      batch_count = 4
      allow(event_manager.api_manager).to receive(:send_odp_events).exactly(batch_count).times.with(api_key, api_host, odp_events).and_return(false)

      # create events before starting processing to simulate backlog
      allow(event_manager).to receive(:running?).and_return(true)
      (batch_count - 1).times do
        event_manager.send_event(**events[0])
        event_manager.send_event(**events[1])
      end
      RSpec::Mocks.space.proxy_for(event_manager).remove_stub(:running?)
      event_manager.start!(odp_config)
      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      event_manager.stop!
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).exactly(batch_count).times.with(Logger::DEBUG, 'ODP event queue: flushing on batch size.')
      expect(spy_logger).to have_received(:log).exactly(batch_count).times.with(Logger::DEBUG, 'ODP event queue: flushing batch size 2.')
    end

    it 'should flush with flush signal' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      allow(event_manager.api_manager).to receive(:send_odp_events).once.with(api_key, api_host, odp_events).and_return(false)
      event_manager.start!(odp_config)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      event_manager.flush
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, 'ODP event queue: received flush signal.')
      event_manager.stop!
    end

    it 'should flush multiple times successfully' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      allow(event_manager.api_manager).to receive(:send_odp_events).exactly(4).times.with(api_key, api_host, odp_events).and_return(false)
      event_manager.start!(odp_config)
      flush_count = 4

      flush_count.times do
        event_manager.send_event(**events[0])
        event_manager.send_event(**events[1])
        event_manager.flush
      end
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).to have_received(:log).exactly(flush_count).times.with(Logger::DEBUG, 'ODP event queue: received flush signal.')
      expect(spy_logger).to have_received(:log).exactly(flush_count).times.with(Logger::DEBUG, 'ODP event queue: flushing batch size 2.')

      event_manager.stop!
    end

    it 'should log error on retry failure' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      retry_count = event_manager.instance_variable_get('@retry_count')
      allow(event_manager.api_manager).to receive(:send_odp_events).exactly(retry_count + 1).times.with(api_key, api_host, odp_events).and_return(true)
      event_manager.start!(odp_config)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      event_manager.flush
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).to have_received(:log).exactly(retry_count).times.with(Logger::DEBUG, 'Error dispatching ODP events, scheduled to retry.')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "ODP event send failed (Failed after 3 retries: #{processed_events.to_json}).")

      event_manager.stop!
    end

    it 'should retry on network failure' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      allow(event_manager.api_manager).to receive(:send_odp_events).once.with(api_key, api_host, odp_events).and_return(true, true, false)
      event_manager.start!(odp_config)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      event_manager.flush
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).to have_received(:log).twice.with(Logger::DEBUG, 'Error dispatching ODP events, scheduled to retry.')
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(event_manager.running?).to be true
      event_manager.stop!
    end

    it 'should log error on send failure' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      allow(event_manager.api_manager).to receive(:send_odp_events).once.with(api_key, api_host, odp_events).and_raise(StandardError, 'Unexpected error')
      event_manager.start!(odp_config)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      event_manager.flush
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "ODP event send failed (Error: Unexpected error #{processed_events.to_json}).")
      expect(event_manager.running?).to be true
      event_manager.stop!
    end

    it 'should log debug when odp disabled' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      odp_config = Optimizely::OdpConfig.new
      odp_config.update(nil, nil, nil)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      event_manager.start!(odp_config)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).twice.with(Logger::DEBUG, Optimizely::Helpers::Constants::ODP_LOGS[:ODP_NOT_INTEGRATED])
      expect(event_manager.running?).to be true
      event_manager.stop!
    end

    it 'should log error when queue is full' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      stub_const('Optimizely::Helpers::Constants::ODP_EVENT_MANAGER', {DEFAULT_QUEUE_CAPACITY: 1})
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      event_manager.odp_config = odp_config
      allow(event_manager).to receive(:running?).and_return(true)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      event_manager.flush

      # warning when adding event to full queue
      expect(spy_logger).to have_received(:log).once.with(Logger::WARN, 'ODP event send failed (queue full).')
      # error when trying to flush with full queue
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Error flushing ODP event queue.')
    end

    it 'should log error on exception within thread' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      allow(event_manager).to receive(:add_to_batch).and_raise(StandardError, 'Unexpected error')
      event_manager.start!(odp_config)

      event_manager.send_event(**events[0])
      sleep(0.1)
      event_manager.send_event(**events[0])

      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Uncaught exception processing ODP events. Error: Unexpected error')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'ODP event send failed (Queue is down).')

      event_manager.stop!
    end

    it 'should work with overriden event data' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)

      event = events[0]
      event[:data][:data_source] = 'my-app'
      odp_event = Optimizely::OdpEvent.new(**event)

      expect(odp_event.instance_variable_get('@data')[:data_source]).to eq 'my-app'

      allow(event_manager.api_manager).to receive(:send_odp_events).once.with(api_key, api_host, [odp_event]).and_return(false)
      event_manager.start!(odp_config)

      event_manager.send_event(**event)
      event_manager.flush
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      event_manager.stop!
    end

    it 'should flush when timeout is reached' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      allow(event_manager.api_manager).to receive(:send_odp_events).once.with(api_key, api_host, odp_events).and_return(false)
      event_manager.instance_variable_set('@flush_interval', 0.5)
      event_manager.start!(odp_config)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?
      sleep(1)

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, 'ODP event queue: flushing on interval.')
      event_manager.stop!
    end

    it 'should discard events received before datafile is ready and process normally' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      odp_config = Optimizely::OdpConfig.new
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      allow(event_manager.api_manager).to receive(:send_odp_events).once.with(api_key, api_host, odp_events).and_return(false)
      event_manager.start!(odp_config)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])

      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?
      odp_config.api_key = api_key
      odp_config.api_host = api_host
      odp_config.segments_to_check = []
      event_manager.update_config

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      event_manager.flush

      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).twice.with(Logger::DEBUG, 'ODP event queue: cannot send before the datafile has loaded.')
      expect(spy_logger).to have_received(:log).twice.with(Logger::DEBUG, 'ODP event queue: adding event.')
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, 'ODP event queue: received flush signal.')
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, 'ODP event queue: received update config signal.')
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, 'ODP event queue: flushing batch size 2.')
      event_manager.stop!
    end

    it 'should discard events before and after odp is disabled' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      odp_config = Optimizely::OdpConfig.new
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      expect(event_manager.api_manager).not_to receive(:send_odp_events)
      event_manager.start!(odp_config)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])

      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      odp_config.update(nil, nil, [])
      event_manager.update_config

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])

      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).twice.with(Logger::DEBUG, 'ODP event queue: cannot send before the datafile has loaded.')
      expect(spy_logger).to have_received(:log).twice.with(Logger::DEBUG, Optimizely::Helpers::Constants::ODP_LOGS[:ODP_NOT_INTEGRATED])
      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      event_manager.stop!
    end

    it 'should begin discarding events if odp is disabled after being enabled' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      odp_config = Optimizely::OdpConfig.new(api_key, api_host)
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      allow(event_manager.api_manager).to receive(:send_odp_events).once.with(api_key, api_host, odp_events).and_return(false)
      event_manager.start!(odp_config)

      event_manager.instance_variable_set('@batch_size', 2)

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      odp_config.api_key = nil
      odp_config.api_host = nil
      odp_config.segments_to_check = []
      event_manager.update_config

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])

      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, 'ODP event queue: flushing batch size 2.')
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, 'ODP event queue: received update config signal.')
      expect(spy_logger).to have_received(:log).twice.with(Logger::DEBUG, Optimizely::Helpers::Constants::ODP_LOGS[:ODP_NOT_INTEGRATED])
      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      event_manager.stop!
    end

    it 'should discard events if odp is disabled after there are events in queue' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      odp_config = Optimizely::OdpConfig.new(api_key, api_host)

      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      event_manager.odp_config = odp_config
      event_manager.instance_variable_set('@batch_size', 3)

      allow(event_manager.api_manager).to receive(:send_odp_events).once.with(api_key, api_host, odp_events).and_return(false)
      allow(event_manager).to receive(:running?).and_return(true)
      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])

      RSpec::Mocks.space.proxy_for(event_manager).remove_stub(:running?)

      event_manager.start!(odp_config)
      odp_config.update(nil, nil, [])
      event_manager.update_config

      event_manager.send_event(**events[0])
      event_manager.send_event(**events[1])
      event_manager.send_event(**events[0])
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?

      expect(event_manager.instance_variable_get('@current_batch').length).to eq 0
      expect(spy_logger).to have_received(:log).exactly(3).times.with(Logger::DEBUG, Optimizely::Helpers::Constants::ODP_LOGS[:ODP_NOT_INTEGRATED])
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      event_manager.stop!
    end

    it 'should reject events submitted before odp_config is set' do
      event_manager = Optimizely::OdpEventManager.new(logger: spy_logger)
      expect(event_manager).not_to receive(:dispatch)
      event_manager.send_event(**events[0])

      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, 'ODP event queue: cannot send before config has been set.')
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end
  end
end
