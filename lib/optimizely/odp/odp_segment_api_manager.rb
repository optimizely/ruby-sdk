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
require_relative '../exceptions'

module Optimizely
  class OdpSegmentApiManager
    # Interface that handles fetching audience segments.

    def initialize(logger: nil, proxy_config: nil, timeout: nil)
      @logger = logger || NoOpLogger.new
      @proxy_config = proxy_config
      @timeout = timeout || Optimizely::Helpers::Constants::ODP_GRAPHQL_API_CONFIG[:REQUEST_TIMEOUT]
    end

    # Fetch segments from the ODP GraphQL API.
    #
    # @param api_key - public api key
    # @param api_host - domain url of the host
    # @param user_key - vuid or fs_user_id (client device id or fullstack id)
    # @param user_value - value of user_key
    # @param segments_to_check - array of segments to check

    def fetch_segments(api_key, api_host, user_key, user_value, segments_to_check)
      url = "#{api_host}/v3/graphql"

      headers = {'Content-Type' => 'application/json', 'x-api-key' => api_key.to_s}

      payload = {
        query: 'query($userId: String, $audiences: [String]) {' \
               "customer(#{user_key}: $userId) " \
               '{audiences(subset: $audiences) {edges {node {name state}}}}}',
        variables: {
          userId: user_value.to_s,
          audiences: segments_to_check || []
        }
      }.to_json

      begin
        response = Helpers::HttpUtils.make_request(
          url, :post, payload, headers, @timeout, @proxy_config
        )
      rescue SocketError, Timeout::Error, Net::ProtocolError, Errno::ECONNRESET => e
        @logger.log(Logger::DEBUG, "GraphQL download failed: #{e}")
        log_segments_failure('network error')
        return nil
      rescue Errno::EINVAL, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, HTTPUriError => e
        log_segments_failure(e)
        return nil
      end

      status = response.code.to_i
      if status >= 400
        log_segments_failure(status)
        return nil
      end

      begin
        response = JSON.parse(response.body)
      rescue JSON::ParserError
        log_segments_failure('JSON decode error')
        return nil
      end

      if response.include?('errors')
        error = response['errors'].first if response['errors'].is_a? Array
        error_code = extract_component(error, 'extensions', 'code')
        if error_code == 'INVALID_IDENTIFIER_EXCEPTION'
          log_segments_failure('invalid identifier', Logger::WARN)
        else
          error_class = extract_component(error, 'extensions', 'classification') || 'decode error'
          log_segments_failure(error_class)
        end
        return nil
      end

      audiences = extract_component(response, 'data', 'customer', 'audiences', 'edges')
      unless audiences
        log_segments_failure('decode error')
        return nil
      end

      audiences.filter_map do |edge|
        name = extract_component(edge, 'node', 'name')
        state = extract_component(edge, 'node', 'state')
        unless name && state
          log_segments_failure('decode error')
          return nil
        end
        state == 'qualified' ? name : nil
      end
    end

    private

    def log_segments_failure(message, level = Logger::ERROR)
      @logger.log(level, format(Optimizely::Helpers::Constants::ODP_LOGS[:FETCH_SEGMENTS_FAILED], message))
    end

    def extract_component(hash, *components)
      hash.dig(*components) if hash.is_a? Hash
    rescue TypeError
      nil
    end
  end
end
