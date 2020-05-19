# frozen_string_literal: true

#
#    Copyright 2016-2017, 2019, Optimizely and contributors
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

require 'net/http'

module Optimizely
  class NoOpEventDispatcher
    # Class providing dispatch_event method which does nothing.

    def dispatch_event(event); end
  end

  class EventDispatcher
    # @api constants
    REQUEST_TIMEOUT = 10

    def initialize(logger: nil, error_handler: nil)
      @logger = logger || NoOpLogger.new
      @error_handler = error_handler || NoOpErrorHandler.new
    end

    # Dispatch the event being represented by the Event object.
    #
    # @param event - Event object
    def dispatch_event(event)
      uri = URI.parse(event.url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = REQUEST_TIMEOUT
      http.use_ssl = true

      if event.http_verb == :get
        request = Net::HTTP::Get.new(uri.request_uri)

      elsif event.http_verb == :post
        request = Net::HTTP::Post.new(uri.request_uri)
        request.body = event.params.to_json
      end

      # set headers
      event.headers&.each do |key, val|
        request[key] = val
      end

      response = http.request(request)

      error_msg = "Event failed to dispatch with response code: #{response.code}"

      case response.code.to_i
      when 400...500
        @logger.log(Logger::ERROR, error_msg)
        @error_handler.handle_error(HTTPCallError.new("HTTP Client Error: #{response.code}"))

      when 500...600
        @logger.log(Logger::ERROR, error_msg)
        @error_handler.handle_error(HTTPCallError.new("HTTP Server Error: #{response.code}"))
      else
        @logger.log(Logger::DEBUG, 'event successfully sent with response code ' + response.code.to_s)
      end
    rescue Timeout::Error => e
      @logger.log(Logger::ERROR, "Request Timed out. Error: #{e}")
      @error_handler.handle_error(e)

      # Returning Timeout error to retain existing behavior.
      e
    rescue StandardError => e
      @logger.log(Logger::ERROR, "Event failed to dispatch. Error: #{e}")
      @error_handler.handle_error(e)
      nil
    end
  end
end
