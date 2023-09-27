# frozen_string_literal: true

#
#    Copyright 2019, 2022, Optimizely and contributors
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
require_relative 'odp_event_api_manager'
require_relative '../helpers/constants'
require_relative 'odp_event'

module Optimizely
  class OdpEventManager
    # Events passed to the OdpEventManager are immediately added to an EventQueue.
    # The OdpEventManager maintains a single consumer thread that pulls events off of
    # the BlockingQueue and buffers them for either a configured batch size or for a
    # maximum duration before the resulting OdpEvent is sent to Odp.

    attr_reader :batch_size, :api_manager, :logger
    attr_accessor :odp_config

    def initialize(
      api_manager: nil,
      logger: NoOpLogger.new,
      proxy_config: nil,
      request_timeout: nil,
      flush_interval: nil
    )
      @odp_config = nil
      @api_host = nil
      @api_key = nil

      @mutex = Mutex.new
      @event_queue = SizedQueue.new(Optimizely::Helpers::Constants::ODP_EVENT_MANAGER[:DEFAULT_QUEUE_CAPACITY])
      @queue_capacity = Helpers::Constants::ODP_EVENT_MANAGER[:DEFAULT_QUEUE_CAPACITY]
      # received signal should be sent after adding item to event_queue
      @received = ConditionVariable.new
      @logger = logger
      @api_manager = api_manager || OdpEventApiManager.new(logger: @logger, proxy_config: proxy_config, timeout: request_timeout)
      @flush_interval = flush_interval || Helpers::Constants::ODP_EVENT_MANAGER[:DEFAULT_FLUSH_INTERVAL_SECONDS]
      @batch_size = @flush_interval&.zero? ? 1 : Helpers::Constants::ODP_EVENT_MANAGER[:DEFAULT_BATCH_SIZE]
      @flush_deadline = 0
      @retry_count = Helpers::Constants::ODP_EVENT_MANAGER[:DEFAULT_RETRY_COUNT]
      # current_batch should only be accessed by processing thread
      @current_batch = []
      @thread = nil
      @thread_exception = false
    end

    def start!(odp_config)
      if running?
        @logger.log(Logger::WARN, 'Service already started.')
        return
      end

      @odp_config = odp_config
      @api_host = odp_config.api_host
      @api_key = odp_config.api_key

      @thread = Thread.new { run }
      @logger.log(Logger::INFO, 'Starting scheduler.')
    end

    def flush
      begin
        @event_queue.push(:FLUSH_SIGNAL, true)
      rescue ThreadError
        @logger.log(Logger::ERROR, 'Error flushing ODP event queue.')
        return
      end

      @mutex.synchronize do
        @received.signal
      end
    end

    def update_config
      begin
        # Adds update config signal to event_queue.
        @event_queue.push(:UPDATE_CONFIG, true)
      rescue ThreadError
        @logger.log(Logger::ERROR, 'Error updating ODP config for the event queue')
      end

      @mutex.synchronize do
        @received.signal
      end
    end

    def dispatch(event)
      if @thread_exception
        @logger.log(Logger::ERROR, format(Helpers::Constants::ODP_LOGS[:ODP_EVENT_FAILED], 'Queue is down'))
        return
      end

      # if the processor has been explicitly stopped. Don't accept tasks
      unless running?
        @logger.log(Logger::WARN, 'ODP event queue is shutdown, not accepting events.')
        return
      end

      begin
        @logger.log(Logger::DEBUG, 'ODP event queue: adding event.')
        @event_queue.push(event, true)
      rescue => e
        @logger.log(Logger::WARN, format(Helpers::Constants::ODP_LOGS[:ODP_EVENT_FAILED], e.message))
        return
      end

      @mutex.synchronize do
        @received.signal
      end
    end

    def send_event(type:, action:, identifiers:, data:)
      case @odp_config&.odp_state
      when nil
        @logger.log(Logger::DEBUG, 'ODP event queue: cannot send before config has been set.')
        return
      when OdpConfig::ODP_CONFIG_STATE[:UNDETERMINED]
        @logger.log(Logger::DEBUG, 'ODP event queue: cannot send before the datafile has loaded.')
        return
      when OdpConfig::ODP_CONFIG_STATE[:NOT_INTEGRATED]
        @logger.log(Logger::DEBUG, Helpers::Constants::ODP_LOGS[:ODP_NOT_INTEGRATED])
        return
      end

      event = Optimizely::OdpEvent.new(type: type, action: action, identifiers: identifiers, data: data)
      dispatch(event)
    end

    def stop!
      return unless running?

      begin
        @event_queue.push(:SHUTDOWN_SIGNAL, true)
      rescue ThreadError
        @logger.log(Logger::ERROR, 'Error stopping ODP event queue.')
        return
      end

      @event_queue.close

      @mutex.synchronize do
        @received.signal
      end

      @logger.log(Logger::INFO, 'Stopping ODP event queue.')

      @thread.join

      @logger.log(Logger::ERROR, format(Helpers::Constants::ODP_LOGS[:ODP_EVENT_FAILED], @current_batch.to_json)) unless @current_batch.empty?
    end

    def running?
      !!@thread && !!@thread.status && !@event_queue.closed?
    end

    private

    def run
      loop do
        @mutex.synchronize do
          @received.wait(@mutex, queue_timeout) if @event_queue.empty?
        end

        begin
          item = @event_queue.pop(true)
        rescue ThreadError => e
          raise unless e.message == 'queue empty'

          item = nil
        end

        case item
        when :SHUTDOWN_SIGNAL
          @logger.log(Logger::DEBUG, 'ODP event queue: received shutdown signal.')
          break

        when :FLUSH_SIGNAL
          @logger.log(Logger::DEBUG, 'ODP event queue: received flush signal.')
          flush_batch!

        when :UPDATE_CONFIG
          @logger.log(Logger::DEBUG, 'ODP event queue: received update config signal.')
          process_config_update

        when Optimizely::OdpEvent
          add_to_batch(item)

        when nil && !@current_batch.empty?
          @logger.log(Logger::DEBUG, 'ODP event queue: flushing on interval.')
          flush_batch!
        end
      end
    rescue SignalException
      @thread_exception = true
      @logger.log(Logger::ERROR, 'Interrupted while processing ODP events.')
    rescue => e
      @thread_exception = true
      @logger.log(Logger::ERROR, "Uncaught exception processing ODP events. Error: #{e.message}")
    ensure
      @logger.log(Logger::INFO, 'Exiting ODP processing loop. Attempting to flush pending events.')
      flush_batch!
    end

    def flush_batch!
      if @current_batch.empty?
        @logger.log(Logger::DEBUG, 'ODP event queue: nothing to flush.')
        return
      end

      if @api_key.nil? || @api_host.nil?
        @logger.log(Logger::DEBUG, Helpers::Constants::ODP_LOGS[:ODP_NOT_INTEGRATED])
        @current_batch.clear
        return
      end

      @logger.log(Logger::DEBUG, "ODP event queue: flushing batch size #{@current_batch.length}.")
      should_retry = false

      i = 0
      while i < @retry_count
        begin
          should_retry = @api_manager.send_odp_events(@api_key, @api_host, @current_batch)
        rescue StandardError => e
          should_retry = false
          @logger.log(Logger::ERROR, format(Helpers::Constants::ODP_LOGS[:ODP_EVENT_FAILED], "Error: #{e.message} #{@current_batch.to_json}"))
        end
        break unless should_retry

        @logger.log(Logger::DEBUG, 'Error dispatching ODP events, scheduled to retry.') if i < @retry_count
        i += 1
      end

      @logger.log(Logger::ERROR, format(Helpers::Constants::ODP_LOGS[:ODP_EVENT_FAILED], "Failed after #{i} retries: #{@current_batch.to_json}")) if should_retry

      @current_batch.clear
    end

    def add_to_batch(event)
      set_flush_deadline if @current_batch.empty?

      @current_batch << event
      return unless @current_batch.length >= @batch_size

      @logger.log(Logger::DEBUG, 'ODP event queue: flushing on batch size.')
      flush_batch!
    end

    def set_flush_deadline
      # Sets time that next flush will occur.
      @flush_deadline = Time.new + @flush_interval
    end

    def time_till_flush
      # Returns seconds until next flush; no less than 0.
      [0, @flush_deadline - Time.new].max
    end

    def queue_timeout
      # Returns seconds until next flush or None if current batch is empty.
      return nil if @current_batch.empty?

      time_till_flush
    end

    def process_config_update
      # Updates the configuration used to send events.
      flush_batch! unless @current_batch.empty?

      @api_key = @odp_config&.api_key
      @api_host = @odp_config&.api_host
    end
  end
end
