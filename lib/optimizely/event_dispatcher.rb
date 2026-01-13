# frozen_string_literal: true

#
#    Copyright 2016-2017, 2019-2020, 2022 Optimizely and contributors
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
require_relative 'exceptions'
require_relative 'helpers/http_utils'
require_relative 'helpers/constants'

module Optimizely
  class NoOpEventDispatcher
    # Class providing dispatch_event method which does nothing.

    def dispatch_event(event); end
  end

  class EventDispatcher
    def initialize(logger: nil, error_handler: nil, proxy_config: nil)
      @logger = logger || NoOpLogger.new
      @error_handler = error_handler || NoOpErrorHandler.new
      @proxy_config = proxy_config
    end

    # Dispatch the event being represented by the Event object.
    #
    # @param event - Event object
    def dispatch_event(event)
      retry_count = 0
      max_retries = Helpers::Constants::EVENT_DISPATCH_CONFIG[:MAX_RETRIES]

      while retry_count < max_retries
        begin
          response = Helpers::HttpUtils.make_request(
            event.url, event.http_verb, event.params.to_json, event.headers, Helpers::Constants::EVENT_DISPATCH_CONFIG[:REQUEST_TIMEOUT], @proxy_config
          )

          error_msg = "Event failed to dispatch with response code: #{response.code}"

          case response.code.to_i
          when 400...500
            @logger.log(Logger::ERROR, error_msg)
            @error_handler.handle_error(HTTPCallError.new("HTTP Client Error: #{response.code}"))
            # Don't retry on 4xx client errors
            return

          when 500...600
            @logger.log(Logger::ERROR, error_msg)
            @error_handler.handle_error(HTTPCallError.new("HTTP Server Error: #{response.code}"))
            # Retry on 5xx server errors
            retry_count += 1
            if retry_count < max_retries
              delay = calculate_retry_interval(retry_count - 1)
              @logger.log(Logger::DEBUG, "Retrying event dispatch (attempt #{retry_count} of #{max_retries - 1}) after #{delay}s")
              sleep(delay)
            end
          else
            @logger.log(Logger::DEBUG, "event successfully sent with response code #{response.code}")
            return
          end
        rescue Timeout::Error => e
          @logger.log(Logger::ERROR, "Request Timed out. Error: #{e}")
          @error_handler.handle_error(e)

          retry_count += 1
          # Returning Timeout error to retain existing behavior.
          return e unless retry_count < max_retries

          delay = calculate_retry_interval(retry_count - 1)
          @logger.log(Logger::DEBUG, "Retrying event dispatch (attempt #{retry_count} of #{max_retries - 1}) after #{delay}s")
          sleep(delay)
        rescue StandardError => e
          @logger.log(Logger::ERROR, "Event failed to dispatch. Error: #{e}")
          @error_handler.handle_error(e)

          retry_count += 1
          return nil unless retry_count < max_retries

          delay = calculate_retry_interval(retry_count - 1)
          @logger.log(Logger::DEBUG, "Retrying event dispatch (attempt #{retry_count} of #{max_retries - 1}) after #{delay}s")
          sleep(delay)
        end
      end
    end

    private

    # Calculate exponential backoff interval: 200ms, 400ms, 800ms, ... capped at 1s
    #
    # @param retry_count - Zero-based retry count
    # @return [Float] - Delay in seconds
    def calculate_retry_interval(retry_count)
      initial_interval = Helpers::Constants::EVENT_DISPATCH_CONFIG[:INITIAL_RETRY_INTERVAL]
      max_interval = Helpers::Constants::EVENT_DISPATCH_CONFIG[:MAX_RETRY_INTERVAL]
      interval = initial_interval * (2**retry_count)
      [interval, max_interval].min
    end
  end
end
