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
require 'optimizely/event/batch_event_processor'
require 'optimizely/event/user_event_factory'
require 'optimizely/exceptions'
require 'optimizely/event_dispatcher'
require 'optimizely/error_handler'
require 'optimizely/helpers/constants'
require 'optimizely/helpers/validator'
require 'optimizely/logger'
describe Optimizely::BatchEventProcessor do
  WebMock.allow_net_connect!
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:event) { project_config.get_event_from_key('test_event') }
  let(:log_url) { 'https://logx.optimizely.com/v1/events' }
  let(:post_headers) { {'Content-Type' => 'application/json'} }

  MAX_BATCH_SIZE = 10
  MAX_DURATION_MS = 1000

  before(:example) do
    @event_queue = SizedQueue.new(100)
    @event_dispatcher = Optimizely::EventDispatcher.new
    allow(@event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

    @event_processor = Optimizely::BatchEventProcessor.new(
      event_queue: @event_queue,
      event_dispatcher: @event_dispatcher,
      batch_size: MAX_BATCH_SIZE,
      flush_interval: MAX_DURATION_MS,
      logger: spy_logger
    )
  end

  after(:example) do
    @event_processor.stop!
    @event_queue.clear
  end

  it 'should log waring when service is already started' do
    @event_processor.start!
    expect(spy_logger).to have_received(:log).with(Logger::WARN, 'Service already started.').once
  end

  it 'return return empty event queue and dispatch log event when event is processed' do
    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)

    @event_processor.process(conversion_event)
    sleep 1.5

    expect(@event_processor.event_queue.length).to eq(0)
    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).once
  end

  it 'should flush the current batch when deadline exceeded' do
    user_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    logger = spy('logger')
    event_processor = Optimizely::BatchEventProcessor.new(
      event_queue: @event_queue,
      event_dispatcher: @event_dispatcher,
      batch_size: MAX_BATCH_SIZE,
      flush_interval: MAX_DURATION_MS * 3,
      logger: logger
    )
    sleep 0.025
    event_processor.process(user_event)

    sleep 1
    expect(event_processor.event_queue.length).to eq(0)
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Deadline exceeded flushing current batch.')
  end

  it 'should flush the current batch when max batch size' do
    allow(Optimizely::EventFactory).to receive(:create_log_event).with(any_args)
    expected_batch = []
    counter = 0
    until counter >= 11
      event['key'] = event['key'] + counter.to_s
      user_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
      expected_batch << user_event
      @event_processor.process(user_event)
      counter += 1
    end

    sleep 1

    expected_batch.pop # Removes 11th element
    expect(@event_processor.current_batch.size).to be 10

    expect(Optimizely::EventFactory).to have_received(:create_log_event).with(expected_batch, spy_logger).once
    expect(@event_dispatcher).to have_received(:dispatch_event).with(
      Optimizely::EventFactory.create_log_event(expected_batch, spy_logger)
    ).once
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, "Adding user event: #{event['key']} to batch.").exactly(10).times
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Flushing on max batch size!').once
  end

  it 'should dispatch the event when flush is called' do
    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)

    event_processor = Optimizely::BatchEventProcessor.new(
      event_queue: @event_queue,
      event_dispatcher: @event_dispatcher,
      batch_size: MAX_BATCH_SIZE,
      flush_interval: MAX_DURATION_MS / 2,
      logger: spy_logger
    )

    event_processor.process(conversion_event)
    event_processor.flush
    sleep 1.5

    event_processor.process(conversion_event)
    event_processor.flush
    sleep 1.5

    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).twice

    expect(event_processor.event_queue.length).to eq(0)
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Received flush signal.').twice
  end

  it 'should flush on mismatch revision' do
    allow(project_config).to receive(:revision).and_return('1', '2')
    user_event1 = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    user_event2 = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(user_event1, spy_logger)

    expect(user_event1.event_context[:revision]).to eq('1')
    @event_processor.process(user_event1)

    expect(user_event2.event_context[:revision]).to eq('2')
    @event_processor.process(user_event2)

    sleep 0.25

    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).once

    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Revisions mismatched: Flushing current batch.').once
    expect(spy_logger).not_to have_received(:log).with(Logger::DEBUG, 'Deadline exceeded flushing current batch.')
  end

  it 'should flush on mismatch project id' do
    allow(project_config).to receive(:project_id).and_return('X', 'Y')
    user_event1 = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    user_event2 = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(user_event1, spy_logger)

    expect(user_event1.event_context[:project_id]).to eq('X')
    @event_processor.process(user_event1)

    expect(user_event2.event_context[:project_id]).to eq('Y')
    @event_processor.process(user_event2)

    sleep 0.25

    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).once

    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Project Ids mismatched: Flushing current batch.').once
    expect(spy_logger).not_to have_received(:log).with(Logger::DEBUG, 'Deadline exceeded flushing current batch.')
  end

  it 'should process and halt event when start or stop are called' do
    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)

    @event_processor.process(conversion_event)
    sleep 1.75
    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).once

    @event_processor.stop!
    @event_processor.process(conversion_event)
    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).once
    @event_processor.start!
    @event_processor.stop!
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Deadline exceeded flushing current batch.').at_least(1).times
  end

  it 'should not dispatch event when close is called during process' do
    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)

    @event_processor.process(conversion_event)
    @event_processor.stop!
    expect(@event_dispatcher).not_to have_received(:dispatch_event)
  end
end
