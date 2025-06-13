# frozen_string_literal: true

#
#    Copyright 2025 Optimizely and contributors
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
require 'optimizely/helpers/http_utils'
require 'optimizely/helpers/constants'

module Optimizely
  # Default constants for CMAB requests
  DEFAULT_MAX_RETRIES = 3
  DEFAULT_INITIAL_BACKOFF = 0.1 # in seconds (100 ms)
  DEFAULT_MAX_BACKOFF = 10 # in seconds
  DEFAULT_BACKOFF_MULTIPLIER = 2.0
  MAX_WAIT_TIME = 10

  class CmabRetryConfig
    # Configuration for retrying CMAB requests.
    # Contains parameters for maximum retries, backoff intervals, and multipliers.
    attr_reader :max_retries, :initial_backoff, :max_backoff, :backoff_multiplier

    def initialize(max_retries: DEFAULT_MAX_RETRIES, initial_backoff: DEFAULT_INITIAL_BACKOFF, max_backoff: DEFAULT_MAX_BACKOFF, backoff_multiplier: DEFAULT_BACKOFF_MULTIPLIER)
      @max_retries = max_retries
      @initial_backoff = initial_backoff
      @max_backoff = max_backoff
      @backoff_multiplier = backoff_multiplier
    end
  end

  class DefaultCmabClient
    # Client for interacting with the CMAB service.
    # Provides methods to fetch decisions with optional retry logic.

    def initialize(http_client = nil, retry_config = nil, logger = nil)
      # Initialize the CMAB client.
      # Args:
      #   http_client: HTTP client for making requests.
      #   retry_config: Configuration for retry settings.
      #   logger: Logger for logging errors and info.
      @http_client = http_client || DefaultHttpClient.new
      @retry_config = retry_config || CmabRetryConfig.new
      @logger = logger || NoOpLogger.new
    end

    def fetch_decision(rule_id, user_id, attributes, cmab_uuid, timeout: MAX_WAIT_TIME)
      # Fetches a decision from the CMAB service.
      # Args:
      #   rule_id: The rule ID for the experiment.
      #   user_id: The user ID for the request.
      #   attributes: User attributes for the request.
      #   cmab_uuid: Unique identifier for the CMAB request.
      #   timeout: Maximum wait time for the request to respond in seconds. (default is 10 seconds).
      # Returns:
      #   The variation ID.
      url = "https://prediction.cmab.optimizely.com/predict/#{rule_id}"
      cmab_attributes = attributes.map { |key, value| {'id' => key.to_s, 'value' => value, 'type' => 'custom_attribute'} }

      request_body = {
        instances: [{
          visitorId: user_id,
          experimentId: rule_id,
          attributes: cmab_attributes,
          cmabUUID: cmab_uuid
        }]
      }

      if @retry_config && @retry_config.max_retries.to_i.positive?
        _do_fetch_with_retry(url, request_body, @retry_config, timeout)
      else
        _do_fetch(url, request_body, timeout)
      end
    end

    def _do_fetch(url, request_body, timeout)
      # Perform a single fetch request to the CMAB prediction service.

      # Args:
      #   url: The endpoint URL.
      #   request_body: The request payload.
      #   timeout: Maximum wait time for the request to respond in seconds.
      # Returns:
      #   The variation ID from the response.

      headers = {'Content-Type' => 'application/json'}
      begin
        response = @http_client.post(url, json: request_body, headers: headers, timeout: timeout.to_i)
      rescue StandardError => e
        error_message = Optimizely::Helpers::Constants::CMAB_FETCH_FAILED % e.message
        @logger.log(Logger::ERROR, error_message)
        raise CmabFetchError, error_message
      end

      unless (200..299).include?(response.status_code)
        error_message = Optimizely::Helpers::Constants::CMAB_FETCH_FAILED % response.status_code
        @logger.log(Logger::ERROR, error_message)
        raise CmabFetchError, error_message
      end

      begin
        body = response.json
      rescue JSON::ParserError, Optimizely::CmabInvalidResponseError
        error_message = Optimizely::Helpers::Constants::INVALID_CMAB_FETCH_RESPONSE
        @logger.log(Logger::ERROR, error_message)
        raise CmabInvalidResponseError, error_message
      end

      unless validate_response(body)
        error_message = Optimizely::Helpers::Constants::INVALID_CMAB_FETCH_RESPONSE
        @logger.log(Logger::ERROR, error_message)
        raise CmabInvalidResponseError, error_message
      end

      body['predictions'][0]['variationId']
    end

    def validate_response(body)
      # Validate the response structure from the CMAB service.
      # Args:
      #   body: The JSON response body to validate.
      # Returns:
      #   true if valid, false otherwise.

      body.is_a?(Hash) &&
        body.key?('predictions') &&
        body['predictions'].is_a?(Array) &&
        !body['predictions'].empty? &&
        body['predictions'][0].is_a?(Hash) &&
        body['predictions'][0].key?('variationId')
    end

    def _do_fetch_with_retry(url, request_body, retry_config, timeout)
      # Perform a fetch request with retry logic.
      # Args:
      #   url: The endpoint URL.
      #   request_body: The request payload.
      #   retry_config: Configuration for retry settings.
      #   timeout: Maximum wait time for the request to respond in seconds.
      # Returns:
      #   The variation ID from the response.

      backoff = retry_config.initial_backoff

      (0..retry_config.max_retries).each do |attempt|
        variation_id = _do_fetch(url, request_body, timeout)
        return variation_id
      rescue StandardError => e
        if attempt < retry_config.max_retries
          @logger.log(Logger::INFO, "Retrying CMAB request (attempt #{attempt + 1}) after #{backoff} seconds...")
          Kernel.sleep(backoff)

          backoff = [
            backoff * retry_config.backoff_multiplier,
            retry_config.max_backoff
          ].min
        else
          @logger.log(Logger::ERROR, "Max retries exceeded for CMAB request: #{e.message}")
          raise Optimizely::CmabFetchError, "CMAB decision fetch failed (#{e.message})."
        end
      end
    end
  end

  class DefaultHttpClient
    # Default HTTP client for making requests.
    # Uses Optimizely::Helpers::HttpUtils to make requests.

    def post(url, json: nil, headers: {}, timeout: nil)
      # Makes a POST request to the specified URL with JSON body and headers.
      # Args:
      #   url: The endpoint URL.
      #   json: The JSON payload to send in the request body.
      #   headers: Additional headers for the request.
      #   timeout: Maximum wait time for the request to respond in seconds.
      # Returns:
      #   The response object.

      response = Optimizely::Helpers::HttpUtils.make_request(url, :post, json.to_json, headers, timeout)

      HttpResponseAdapter.new(response)
    end

    class HttpResponseAdapter
      # Adapter for HTTP response to provide a consistent interface.
      # Args:
      #   response: The raw HTTP response object.

      def initialize(response)
        @response = response
      end

      def status_code
        @response.code.to_i
      end

      def json
        JSON.parse(@response.body)
      rescue JSON::ParserError
        raise Optimizely::CmabInvalidResponseError, Optimizely::Helpers::Constants::INVALID_CMAB_FETCH_RESPONSE
      end

      def body
        @response.body
      end
    end
  end

  class NoOpLogger
    # A no-operation logger that does nothing.
    def log(_level, _message); end
  end
end
