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
require_relative 'event_processor'
module Optimizely
  class BatchEventProcessor < EventProcessor
    # BatchEventProcessor is a batched implementation of the Interface EventProcessor.
    # Events passed to the BatchEventProcessor are immediately added to a EventQueue.
    # The BatchEventProcessor maintains a single consumer thread that pulls events off of

    attr_reader :event_queue, :current_batch, :started

    DEFAULT_BATCH_SIZE = 10
    DEFAULT_BATCH_INTERVAL = 30_000
    DEFAULT_QUEUE_CAPACITY = 1000

    FLUSH_SIGNAL = 'FLUSH_SIGNAL'
    SHUTDOWN_SIGNAL = 'SHUTDOWN_SIGNAL'

    def initialize(
      event_queue: SizedQueue.new(DEFAULT_QUEUE_CAPACITY),
      event_dispatcher:,
      batch_size: DEFAULT_BATCH_SIZE,
      flush_interval: DEFAULT_BATCH_INTERVAL,
      logger: NoOpLogger.new
    )
      @event_queue = event_queue
      @event_dispatcher = event_dispatcher
      @batch_size = batch_size
      @flush_interval = flush_interval
      @logger = logger
      @mutex = Mutex.new
      @received = ConditionVariable.new
      @current_batch = []
      @started = false
      start!
    end

    def start!
      if @started == true
        @logger.log(Logger::WARN, 'Service already started.')
        return
      end
      @flushing_interval_deadline = Helpers::DateTimeUtils.create_timestamp + @flush_interval
      @thread = Thread.new { run }
      @started = true
    end

    def flush
      @mutex.synchronize do
        @event_queue << FLUSH_SIGNAL
        @received.signal
      end
    end

    def process(user_event)
      @logger.log(Logger::DEBUG, "Received userEvent: #{user_event}")

      unless @thread.alive?
        @logger.log(Logger::WARN, 'Executor shutdown, not accepting tasks.')
        return
      end

      @mutex.synchronize do
        begin
          @event_queue << user_event
          @received.signal
        rescue Exception
          @logger.log(Logger::WARN, 'Payload not accepted by the queue.')
          return
        end
      end
    end

    def stop!
      return unless @thread.alive?

      @mutex.synchronize do
        @event_queue << SHUTDOWN_SIGNAL
        @received.signal
      end

      @started = false
      @logger.log(Logger::WARN, 'Stopping scheduler.')
      @thread.exit
    end

    private

    def run
      loop do
        if Helpers::DateTimeUtils.create_timestamp > @flushing_interval_deadline
          @logger.log(
            Logger::DEBUG,
            'Deadline exceeded flushing current batch.'
          )
          flush_queue!
        end

        item = nil

        @mutex.synchronize do
          @received.wait(@mutex, 0.05)
          item = @event_queue.pop if @event_queue.length.positive?
        end

        if item.nil?
          @logger.log(Logger::DEBUG, 'Empty item, sleeping for 50ms.')
          sleep(0.05)
          next
        end

        if item == SHUTDOWN_SIGNAL
          @logger.log(Logger::INFO, 'Received shutdown signal.')
          break
        end

        if item == FLUSH_SIGNAL
          @logger.log(Logger::DEBUG, 'Received flush signal.')
          flush_queue!
          next
        end

        if item.is_a? Optimizely::UserEvent
          @logger.log(Logger::DEBUG, "Received add to batch signal. with event: #{item.event['key']}.")
          add_to_batch(item)
        end
      end
    end

    def flush_queue!
      return if @current_batch.empty?

      log_event = Optimizely::EventFactory.create_log_event(@current_batch, @logger)
      begin
        @event_dispatcher.dispatch_event(log_event)
      rescue StandardError => e
        @logger.log(Logger::ERROR, "Error dispatching event: #{log_event} #{e.message}.")
      end
      @current_batch = []
    end

    def add_to_batch(user_event)
      if should_split?(user_event)
        flush_queue!
        @current_batch = []
      end

      # Reset the deadline if starting a new batch.
      @flushing_interval_deadline = (Helpers::DateTimeUtils.create_timestamp + @flush_interval) if @current_batch.empty?

      @logger.log(Logger::DEBUG, "Adding user event: #{user_event.event['key']} to batch.")
      @current_batch << user_event
      return unless @current_batch.length >= @batch_size

      @logger.log(Logger::DEBUG, 'Flushing on max batch size!')
      flush_queue!
    end

    def should_split?(user_event)
      return false if @current_batch.empty?

      current_context = @current_batch.last.event_context

      new_context = user_event.event_context
      # Revisions should match
      unless current_context[:revision] == new_context[:revision]
        @logger.log(Logger::DEBUG, 'Revisions mismatched: Flushing current batch.')
        return true
      end
      # Projects should match
      unless current_context[:project_id] == new_context[:project_id]
        @logger.log(Logger::DEBUG, 'Project Ids mismatched: Flushing current batch.')
        return true
      end
      false
    end
  end
end
