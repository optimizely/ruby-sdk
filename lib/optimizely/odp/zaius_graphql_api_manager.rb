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
  class ZaiusGraphQlApiManager
    # Interface that handles fetching audience segments.

    def initialize(logger: nil, proxy_config: nil)
      @logger = logger || NoOpLogger.new
      @proxy_config = proxy_config
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
        'query' => %'query {customer(#{user_key}: "#{user_value}")' \
                   "{audiences(subset:#{segments_to_check || '[]'}) {edges {node {name state}}}}}"
      }.to_json

      begin
        response = Helpers::HttpUtils.make_request(
          url, :post, payload, headers, Optimizely::Helpers::Constants::ODP_GRAPHQL_API_CONFIG[:REQUEST_TIMEOUT], @proxy_config
        )
      rescue SocketError, Timeout::Error, Net::ProtocolError, Errno::ECONNRESET => e
        @logger.log(Logger::DEBUG, "GraphQL download failed: #{e}")
        log_error(:FETCH_SEGMENTS_FAILED, 'network error')
        return nil
      rescue Errno::EINVAL, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError => e
        log_error(:FETCH_SEGMENTS_FAILED, e)
        return nil
      end

      status = response.code.to_i
      if status >= 400
        log_error(:FETCH_SEGMENTS_FAILED, status)
        return nil
      end

      begin
        response = JSON.parse(response.body)
      rescue JSON::ParserError
        log_error(:FETCH_SEGMENTS_FAILED, 'JSON decode error')
        return nil
      end

      if response.include?('errors')
        error_class = response['errors']&.first&.dig('extensions', 'classification') || 'decode error'
        log_error(:FETCH_SEGMENTS_FAILED, error_class == 'InvalidIdentifierException' ? 'invalid identifier' : error_class)
        return nil
      end

      audiences = response.dig('data', 'customer', 'audiences', 'edges')
      unless audiences
        log_error(:FETCH_SEGMENTS_FAILED, 'decode error')
        return nil
      end

      audiences.filter_map do |edge|
        name = edge.dig('node', 'name')
        state = edge.dig('node', 'state')
        unless name && state
          log_error(:FETCH_SEGMENTS_FAILED, 'decode error')
          return nil
        end
        state == 'qualified' ? name : nil
      end
    end

    private

    def log_error(type, error)
      @logger.log(Logger::ERROR, format(Optimizely::Helpers::Constants::ODP_LOGS[type], error))
    end
  end
end
