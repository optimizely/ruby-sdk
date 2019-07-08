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
module Optimizely
  class AsyncScheduler
    attr_reader :running

    def initialize(callback, interval, auto_update, logger = nil)
      # Sets up AsyncScheduler to execute a callback periodically.
      #
      # callback - Main function to be executed periodically.
      # interval - How many seconds to wait between executions.
      # auto_update - boolean indicates to run infinitely or only once.
      # logger - Optional Provides a logger instance.

      @callback = callback
      @interval = interval
      @auto_update = auto_update
      @running = false
      @thread = nil
      @logger = logger || NoOpLogger.new
    end

    def start!
      # Starts the async scheduler.

      if @running
        @logger.log(
          Logger::WARN,
          'Scheduler is already running. Ignoring .start() call.'
        )
        return
      end

      begin
        @running = true
        @thread = Thread.new { execution_wrapper(@callback) }
      rescue StandardError => e
        @logger.log(
          Logger::ERROR,
          "Couldn't create a new thread for async scheduler. #{e.message}"
        )
      end
    end

    def stop!
      # Stops the async scheduler.

      # If the scheduler is not running do nothing.
      return unless @running

      @running = false
      @thread.exit
    end

    private

    def execution_wrapper(callback)
      # Executes the given callback periodically

      loop do
        begin
          callback.call
        rescue
          @logger.log(
            Logger::ERROR,
            'Something went wrong when running passed function.'
          )
          stop!
        end
        break unless @auto_update

        sleep @interval
      end
    end
  end
end
