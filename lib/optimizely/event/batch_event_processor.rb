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
require_relative '../helpers/validator'
module Optimizely
  class BatchEventProcessor < EventProcessor
    # BatchEventProcessor is a batched implementation of the Interface EventProcessor.
    # Events passed to the BatchEventProcessor are immediately added to an EventQueue.
    # The BatchEventProcessor maintains a single consumer thread that pulls events off of
    # the BlockingQueue and buffers them for either a configured batch size or for a
    # maximum duration before the resulting LogEvent is sent to the NotificationCenter.

    attr_reader :event_queue, :event_dispatcher, :current_batch, :started, :batch_size, :flush_interval

    DEFAULT_BATCH_SIZE = 10
    DEFAULT_BATCH_INTERVAL = 30_000 # interval in milliseconds
    DEFAULT_QUEUE_CAPACITY = 1000
    DEFAULT_TIMEOUT_INTERVAL = 5 # interval in seconds
    MAX_NIL_COUNT = 3

    FLUSH_SIGNAL = 'FLUSH_SIGNAL'
    SHUTDOWN_SIGNAL = 'SHUTDOWN_SIGNAL'

    def initialize(
      event_queue: SizedQueue.new(DEFAULT_QUEUE_CAPACITY),
      event_dispatcher: Optimizely::EventDispatcher.new,
      batch_size: DEFAULT_BATCH_SIZE,
      flush_interval: DEFAULT_BATCH_INTERVAL,
      logger: NoOpLogger.new,
      notification_center: nil
    )
      @event_queue = event_queue
      @logger = logger
      @event_dispatcher = event_dispatcher
      @batch_size = if (batch_size.is_a? Integer) && positive_number?(batch_size)
                      batch_size
                    else
                      @logger.log(Logger::DEBUG, "Setting to default batch_size: #{DEFAULT_BATCH_SIZE}.")
                      DEFAULT_BATCH_SIZE
                    end
      @flush_interval = if positive_number?(flush_interval)
                          flush_interval
                        else
                          @logger.log(Logger::DEBUG, "Setting to default flush_interval: #{DEFAULT_BATCH_INTERVAL} ms.")
                          DEFAULT_BATCH_INTERVAL
                        end
      @notification_center = notification_center
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
      @logger.log(Logger::INFO, 'Starting scheduler.')
      @thread = Thread.new { run }
      @started = true
    end

    def flush
      @event_queue << FLUSH_SIGNAL
    end

    def process(user_event)
      @logger.log(Logger::DEBUG, "Received userEvent: #{user_event}")

      if !@started || !@thread.alive?
        @logger.log(Logger::WARN, 'Executor shutdown, not accepting tasks.')
        return
      end

      begin
        @event_queue.push(user_event, true)
      rescue Exception
        @logger.log(Logger::WARN, 'Payload not accepted by the queue.')
        return
      end
    end

    def stop!
      return unless @started

      @logger.log(Logger::INFO, 'Stopping scheduler.')
      @event_queue << SHUTDOWN_SIGNAL
      @thread.join(DEFAULT_TIMEOUT_INTERVAL)
      @started = false
    end

    private

    def run
      @nil_count = 0
      loop do
        if Helpers::DateTimeUtils.create_timestamp >= @flushing_interval_deadline || @nil_count > MAX_NIL_COUNT
          @logger.log(Logger::DEBUG, 'Deadline exceeded flushing current batch.')
          flush_queue!
          @flushing_interval_deadline = Helpers::DateTimeUtils.create_timestamp + @flush_interval
        end

        item = @event_queue.pop if @event_queue.length.positive? || @nil_count > MAX_NIL_COUNT

        if item.nil?
          sleep(0.5)
          @nil_count += 1
          next
        end

        @nil_count = 0

        if item == SHUTDOWN_SIGNAL
          @logger.log(Logger::DEBUG, 'Received shutdown signal.')
          break
        end

        if item == FLUSH_SIGNAL
          @logger.log(Logger::DEBUG, 'Received flush signal.')
          flush_queue!
          next
        end

        add_to_batch(item) if item.is_a? Optimizely::UserEvent
      end
    rescue SignalException
      @logger.log(Logger::ERROR, 'Interrupted while processing buffer.')
    rescue Exception => e
      @logger.log(Logger::ERROR, "Uncaught exception processing buffer. #{e.message}")
    ensure
      @logger.log(
        Logger::INFO,
        'Exiting processing loop. Attempting to flush pending events.'
      )
      flush_queue!
    end

    def flush_queue!
      return if @current_batch.empty?

      log_event = Optimizely::EventFactory.create_log_event(@current_batch, @logger)
      begin
        @logger.log(
          Logger::INFO,
          'Flushing Queue.'
        )

        @event_dispatcher.dispatch_event(log_event)
        @notification_center&.send_notifications(
          NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT],
          log_event
        )
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

      @logger.log(Logger::DEBUG, "Adding user event: #{user_event} to batch.")
      @current_batch << user_event
      return unless @current_batch.length >= @batch_size

      @logger.log(Logger::DEBUG, 'Flushing on max batch size.')
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

    def positive_number?(value)
      # Returns true if the given value is positive finite number.
      #   false otherwise.
      Helpers::Validator.finite_number?(value) && value.positive?
    end
  end
end
