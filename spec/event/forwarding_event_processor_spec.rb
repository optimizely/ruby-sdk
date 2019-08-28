# frozen_string_literal: true

#
#    Copyright 2019, Optimizely and contributors
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
require 'optimizely/event/forwarding_event_processor'
require 'optimizely/event/user_event_factory'
require 'optimizely/error_handler'
require 'optimizely/helpers/date_time_utils'
require 'optimizely/logger'
describe Optimizely::ForwardingEventProcessor do
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:event) { project_config.get_event_from_key('test_event') }
  let(:log_url) { 'https://logx.optimizely.com/v1/events' }
  let(:post_headers) { {'Content-Type' => 'application/json'} }

  before(:example) do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)
    allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')

    @event_dispatcher = Optimizely::EventDispatcher.new
    allow(@event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
    @conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)

    @expected_endpoint = 'https://logx.optimizely.com/v1/events'
    @expected_conversion_params = {
      account_id: '12001',
      project_id: '111001',
      visitors: [{
        attributes: [{
          entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          type: 'custom',
          value: true
        }],
        visitor_id: 'test_user',
        snapshots: [{
          events: [{
            entity_id: '111095',
            timestamp: Optimizely::Helpers::DateTimeUtils.create_timestamp,
            uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
            key: 'test_event'
          }]
        }]
      }],
      anonymize_ip: false,
      revision: '42',
      client_name: Optimizely::CLIENT_ENGINE,
      enrich_decisions: true,
      client_version: Optimizely::VERSION
    }
  end

  describe '.process' do
    it 'should dispatch log event when valid event is provided' do
      forwarding_event_processor = Optimizely::ForwardingEventProcessor.new(
        @event_dispatcher, spy_logger
      )

      forwarding_event_processor.process(@conversion_event)

      expect(@event_dispatcher).to have_received(:dispatch_event).with(
        Optimizely::Event.new(:post, log_url, @expected_conversion_params, post_headers)
      ).once
    end

    it 'should log an error when dispatch event raises timeout exception' do
      log_event = Optimizely::Event.new(:post, log_url, @expected_conversion_params, post_headers)
      allow(Optimizely::EventFactory).to receive(:create_log_event).and_return(log_event)

      timeout_error = Timeout::Error.new
      allow(@event_dispatcher).to receive(:dispatch_event).and_raise(timeout_error)

      forwarding_event_processor = Optimizely::ForwardingEventProcessor.new(
        @event_dispatcher, spy_logger
      )

      forwarding_event_processor.process(@conversion_event)

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Error dispatching event: #{log_event} Timeout::Error."
      )
    end
  end
end
