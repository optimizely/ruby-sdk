# frozen_string_literal: true

#
#    Copyright 2022, Optimizely and contributors
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

require 'json'

module Optimizely
  class ZaiusRestApiManager
    # Interface that handles sending ODP events.

    def initialize(logger: nil, proxy_config: nil)
      @logger = logger || NoOpLogger.new
      @proxy_config = proxy_config
    end

    # Send events to the ODP Events API.
    #
    # @param api_key - public api key
    # @param api_host - domain url of the host
    # @param events - array of events to send

    def send_odp_events(api_key, api_host, events)
      should_retry = false
      url = "#{api_host}/v3/events"

      headers = {'Content-Type' => 'application/json', 'x-api-key' => api_key.to_s}

      begin
        response = Helpers::HttpUtils.make_request(
          url, :post, events.to_json, headers, Optimizely::Helpers::Constants::ODP_REST_API_CONFIG[:REQUEST_TIMEOUT], @proxy_config
        )
      rescue SocketError, Timeout::Error, Net::ProtocolError, Errno::ECONNRESET
        log_failure('network error')
        should_retry = true
        return should_retry
      rescue Errno::EINVAL, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError => e
        log_failure(e)
        return should_retry
      end

      status = response.code.to_i
      if status >= 400
        log_failure(!response.body.empty? ? response.body : "#{status}: #{response.message}")
        should_retry = status >= 500
      end
      should_retry
    end

    private

    def log_failure(message, level = Logger::ERROR)
      @logger.log(level, format(Optimizely::Helpers::Constants::ODP_LOGS[:ODP_EVENT_FAILED], message))
    end
  end
end
