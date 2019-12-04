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
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:event) { project_config.get_event_from_key('test_event') }

  before(:example) do
    @event_queue = SizedQueue.new(100)
    @event_dispatcher = Optimizely::EventDispatcher.new
    allow(@event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
    @notification_center = Optimizely::NotificationCenter.new(spy_logger, error_handler)
    allow(@notification_center).to receive(:send_notifications)
  end

  after(:example) do
    @event_processor.stop! if @event_processor.instance_of? Optimizely::BatchEventProcessor
  end

  it 'should log waring when service is already started' do
    @event_processor = Optimizely::BatchEventProcessor.new(logger: spy_logger)
    @event_processor.start!
    expect(spy_logger).to have_received(:log).with(Logger::WARN, 'Service already started.').once
  end

  it 'should flush the current batch when flush deadline exceeded' do
    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)

    @event_processor = Optimizely::BatchEventProcessor.new(
      event_dispatcher: @event_dispatcher,
      flush_interval: 100,
      logger: spy_logger,
      notification_center: @notification_center
    )

    @event_processor.process(conversion_event)
    # flush interval is set to 100ms. Wait for 300ms and assert that event is dispatched.
    sleep 1

    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).once
    expect(@notification_center).to have_received(:send_notifications).with(
      Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT],
      log_event
    ).once
    expect(spy_logger).to have_received(:log).with(Logger::INFO, 'Flushing Queue.').once
  end

  it 'should flush the current batch when max batch size met' do
    @event_processor = Optimizely::BatchEventProcessor.new(
      event_dispatcher: @event_dispatcher,
      batch_size: 11,
      flush_interval: 100_000,
      logger: spy_logger
    )

    user_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(user_event, spy_logger)

    allow(Optimizely::EventFactory).to receive(:create_log_event).with(any_args).and_return(log_event)

    expected_batch = []
    11.times do
      expected_batch << user_event
      @event_processor.process(user_event)
    end

    # Wait until other thread has processed the event.
    until @event_processor.event_queue.empty?; end
    until @event_processor.current_batch.empty?; end

    expect(Optimizely::EventFactory).to have_received(:create_log_event).with(expected_batch, spy_logger).once
    expect(@event_dispatcher).to have_received(:dispatch_event).with(
      Optimizely::EventFactory.create_log_event(expected_batch, spy_logger)
    ).once
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Flushing on max batch size.').once
  end

  it 'should dispatch the event when flush is called' do
    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)

    @event_processor = Optimizely::BatchEventProcessor.new(
      event_queue: @event_queue,
      event_dispatcher: @event_dispatcher,
      flush_interval: 100_000,
      logger: spy_logger
    )

    @event_processor.process(conversion_event)
    @event_processor.flush

    @event_processor.process(conversion_event)
    @event_processor.flush

    # Wait until other thread has processed the event.
    until @event_processor.event_queue.empty?; end
    until @event_processor.current_batch.empty?; end

    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).twice
    expect(@event_processor.event_queue.length).to eq(0)
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Received flush signal.').twice
  end

  it 'should flush on mismatch revision' do
    @event_processor = Optimizely::BatchEventProcessor.new(
      event_dispatcher: @event_dispatcher,
      logger: spy_logger,
      notification_center: @notification_center
    )

    allow(project_config).to receive(:revision).and_return('1', '2')
    user_event1 = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    user_event2 = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(user_event1, spy_logger)

    expect(user_event1.event_context[:revision]).to eq('1')
    @event_processor.process(user_event1)
    # Wait until other thread has processed the event.
    while @event_processor.current_batch.length != 1; end

    expect(user_event2.event_context[:revision]).to eq('2')
    @event_processor.process(user_event2)
    @event_processor.process(user_event2)
    # Wait until other thread has processed the event.
    while @event_processor.current_batch.length != 2; end

    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).once
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Revisions mismatched: Flushing current batch.').once
  end

  it 'should flush on mismatch project id' do
    @event_processor = Optimizely::BatchEventProcessor.new(
      event_dispatcher: @event_dispatcher,
      logger: spy_logger,
      notification_center: @notification_center
    )

    allow(project_config).to receive(:project_id).and_return('X', 'Y')
    user_event1 = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    user_event2 = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(user_event1, spy_logger)

    expect(user_event1.event_context[:project_id]).to eq('X')
    @event_processor.process(user_event1)
    # Wait until other thread has processed the event.
    while @event_processor.current_batch.length != 1; end

    expect(user_event2.event_context[:project_id]).to eq('Y')
    @event_processor.process(user_event2)
    @event_processor.process(user_event2)
    # Wait until other thread has processed the event.
    while @event_processor.current_batch.length != 2; end

    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).once
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Project Ids mismatched: Flushing current batch.').once
    expect(spy_logger).not_to have_received(:log).with(Logger::DEBUG, 'Deadline exceeded flushing current batch.')
  end

  it 'should set default batch size when provided invalid' do
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher)
    expect(event_processor.batch_size).to eq(10)
    event_processor.stop!
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, batch_size: 'test', logger: spy_logger)
    expect(event_processor.batch_size).to eq(10)
    event_processor.stop!
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, batch_size: [], logger: spy_logger)
    expect(event_processor.batch_size).to eq(10)
    event_processor.stop!
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, batch_size: 0, logger: spy_logger)
    expect(event_processor.batch_size).to eq(10)
    event_processor.stop!
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, batch_size: -5, logger: spy_logger)
    expect(event_processor.batch_size).to eq(10)
    event_processor.stop!
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, batch_size: 5.5, logger: spy_logger)
    expect(event_processor.batch_size).to eq(10)
    event_processor.stop!
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Setting to default batch_size: 10.').exactly(5).times
  end

  it 'should set batch size when provided valid' do
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, batch_size: 5)
    expect(event_processor.batch_size).to eq(5)
    event_processor.stop!
  end

  it 'should set default flush interval when provided invalid' do
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher)
    expect(event_processor.flush_interval).to eq(30_000)
    event_processor.stop!
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, flush_interval: 'test', logger: spy_logger)
    expect(event_processor.flush_interval).to eq(30_000)
    event_processor.stop!
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, flush_interval: [], logger: spy_logger)
    expect(event_processor.flush_interval).to eq(30_000)
    event_processor.stop!
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, flush_interval: 0, logger: spy_logger)
    expect(event_processor.flush_interval).to eq(30_000)
    event_processor.stop!
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, flush_interval: -5, logger: spy_logger)
    expect(event_processor.flush_interval).to eq(30_000)
    event_processor.stop!
    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Setting to default flush_interval: 30000 ms.').exactly(4).times
  end

  it 'should set flush interval when provided valid' do
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, flush_interval: 2000)
    expect(event_processor.flush_interval).to eq(2000)
    event_processor.stop!
    event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: @event_dispatcher, flush_interval: 0.5)
    expect(event_processor.flush_interval).to eq(0.5)
    event_processor.stop!
  end

  it 'should send log event notification when event is dispatched' do
    @event_processor = Optimizely::BatchEventProcessor.new(
      event_dispatcher: @event_dispatcher,
      logger: spy_logger,
      notification_center: @notification_center
    )

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)

    @event_processor.process(conversion_event)

    # Wait until other thread has processed the event.
    while @event_processor.current_batch.length != 1; end
    @event_processor.flush
    # Wait until other thread has processed the event.
    until @event_processor.current_batch.empty?; end

    expect(@notification_center).to have_received(:send_notifications).with(
      Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT],
      log_event
    ).once

    expect(@event_dispatcher).to have_received(:dispatch_event).with(log_event).once
  end

  it 'should log an error when dispatch event raises timeout exception' do
    @event_processor = Optimizely::BatchEventProcessor.new(
      event_dispatcher: @event_dispatcher,
      logger: spy_logger,
      notification_center: @notification_center
    )

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    allow(Optimizely::EventFactory).to receive(:create_log_event).and_return(log_event)

    timeout_error = Timeout::Error.new
    allow(@event_dispatcher).to receive(:dispatch_event).and_raise(timeout_error)

    @event_processor.process(conversion_event)
    # Wait until other thread has processed the event.
    while @event_processor.current_batch.length != 1; end
    @event_processor.flush
    # Wait until other thread has processed the event.
    until @event_processor.current_batch.empty?; end

    expect(@notification_center).not_to have_received(:send_notifications)
    expect(spy_logger).to have_received(:log).once.with(
      Logger::ERROR,
      "Error dispatching event: #{log_event} Timeout::Error."
    )
  end

  it 'should flush pending events when stop is called' do
    @event_processor = Optimizely::BatchEventProcessor.new(
      event_dispatcher: @event_dispatcher,
      batch_size: 5,
      flush_interval: 10_000,
      logger: spy_logger
    )

    experiment = project_config.get_experiment_from_key('test_experiment')
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', 'test_user', nil)
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)

    allow(Optimizely::EventFactory).to receive(:create_log_event).with(any_args).and_return(log_event)

    expected_batch = []
    4.times do
      user_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
      expected_batch << user_event
      @event_processor.process(user_event)
    end

    # Wait until other thread has processed the event.
    while @event_processor.current_batch.length != 4; end
    expect(@event_dispatcher).not_to have_received(:dispatch_event)

    @event_processor.stop!

    expect(spy_logger).to have_received(:log).with(Logger::INFO, 'Exiting processing loop. Attempting to flush pending events.')
    expect(spy_logger).not_to have_received(:log).with(Logger::DEBUG, 'Flushing on max batch size!')
    expect(@event_dispatcher).to have_received(:dispatch_event).with(
      Optimizely::EventFactory.create_log_event(expected_batch, spy_logger)
    )
  end

  it 'should log a warning when Queue gets full' do
    @event_processor = Optimizely::BatchEventProcessor.new(
      event_queue: SizedQueue.new(10),
      event_dispatcher: @event_dispatcher,
      batch_size: 100,
      flush_interval: 100_000,
      logger: spy_logger
    )

    user_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    11.times do
      @event_processor.process(user_event)
    end

    # Wait until other thread has processed the event.
    while @event_processor.current_batch.length != 10; end
    expect(@event_dispatcher).not_to have_received(:dispatch_event)
    expect(spy_logger).to have_received(:log).with(Logger::WARN, 'Payload not accepted by the queue.').once
  end

  it 'should not process and log when Executor is not running' do
    @event_processor = Optimizely::BatchEventProcessor.new(
      event_dispatcher: @event_dispatcher,
      batch_size: 100,
      flush_interval: 100_000,
      logger: spy_logger
    )

    @event_processor.stop!

    user_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    @event_processor.process(user_event)
    expect(@event_processor.event_queue.length).to eq(0)
    expect(spy_logger).to have_received(:log).with(Logger::WARN, 'Executor shutdown, not accepting tasks.').once
  end
end
