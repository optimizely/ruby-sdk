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

require 'optimizely/logger'
require_relative '../helpers/constants'

module Optimizely
  class OdpConfig
    ODP_CONFIG_STATE = Helpers::Constants::ODP_CONFIG_STATE
    # Contains configuration used for ODP integration.
    #
    # @param api_host - The host URL for the ODP audience segments API (optional).
    # @param api_key - The public API key for the ODP account from which the audience segments will be fetched (optional).
    # @param segments_to_check - An array of all ODP segments used in the current datafile (associated with api_host/api_key).
    def initialize(api_key = nil, api_host = nil, segments_to_check = [])
      @api_key = api_key
      @api_host = api_host
      @segments_to_check = segments_to_check
      @mutex = Mutex.new
      @odp_state = @api_host.nil? || @api_key.nil? ? ODP_CONFIG_STATE[:UNDETERMINED] : ODP_CONFIG_STATE[:INTEGRATED]
    end

    # Replaces the existing configuration
    #
    # @param api_host - The host URL for the ODP audience segments API (optional).
    # @param api_key - The public API key for the ODP account from which the audience segments will be fetched (optional).
    # @param segments_to_check - An array of all ODP segments used in the current datafile (associated with api_host/api_key).
    #
    # @return - True if the provided values were different than the existing values.

    def update(api_key = nil, api_host = nil, segments_to_check = [])
      updated = false
      @mutex.synchronize do
        @odp_state = api_host.nil? || api_key.nil? ? ODP_CONFIG_STATE[:NOT_INTEGRATED] : ODP_CONFIG_STATE[:INTEGRATED]

        if @api_key != api_key || @api_host != api_host || @segments_to_check != segments_to_check
          @api_key = api_key
          @api_host = api_host
          @segments_to_check = segments_to_check
          updated = true
        end
      end

      updated
    end

    # Returns the api host for odp connections
    #
    # @return - The api host.

    def api_host
      @mutex.synchronize { @api_host.clone }
    end

    # Returns the api host for odp connections
    #
    # @return - The api host.

    def api_host=(api_host)
      @mutex.synchronize do
        @api_host = api_host.clone
        if @api_host.nil?
          @odp_state = ODP_CONFIG_STATE[:NOT_INTEGRATED]
        elsif !@api_key.nil?
          @odp_state = ODP_CONFIG_STATE[:INTEGRATED]
        end
      end
    end

    # Returns the api key for odp connections
    #
    # @return - The api key.

    def api_key
      @mutex.synchronize { @api_key.clone }
    end

    # Replace the api key with the provided string
    #
    # @param api_key - An api key

    def api_key=(api_key)
      @mutex.synchronize do
        @api_key = api_key.clone
        if @api_key.nil?
          @odp_state = ODP_CONFIG_STATE[:NOT_INTEGRATED]
        elsif !@api_host.nil?
          @odp_state = ODP_CONFIG_STATE[:INTEGRATED]
        end
      end
    end

    # Returns An array of qualified segments for this user
    #
    # @return - An array of segments names.

    def segments_to_check
      @mutex.synchronize { @segments_to_check.clone }
    end

    # Replace qualified segments with provided segments
    #
    # @param segments - An array of segment names

    def segments_to_check=(segments_to_check)
      @mutex.synchronize { @segments_to_check = segments_to_check.clone }
    end

    # Returns the state of odp integration (UNDETERMINED, INTEGRATED, NOT_INTEGRATED)
    #
    # @return - string

    def odp_state
      @mutex.synchronize { @odp_state }
    end
  end
end
