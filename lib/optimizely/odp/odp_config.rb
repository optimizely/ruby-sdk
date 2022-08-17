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

module Optimizely
  class OdpConfig
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
    end

    # Replaces the existing configuration
    #
    # @param api_host - The host URL for the ODP audience segments API (optional).
    # @param api_key - The public API key for the ODP account from which the audience segments will be fetched (optional).
    # @param segments_to_check - An array of all ODP segments used in the current datafile (associated with api_host/api_key).
    #
    # @return - True if the provided values were different than the existing values.

    def update(api_key = nil, api_host = nil, segments_to_check = [])
      @mutex.synchronize do
        break false if @api_key == api_key && @api_host == api_host && @segments_to_check == segments_to_check

        @api_key = api_key
        @api_host = api_host
        @segments_to_check = segments_to_check
        break true
      end
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
      @mutex.synchronize { @api_host = api_host.clone }
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
      @mutex.synchronize { @api_key = api_key.clone }
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

    # Returns True if odp is integrated
    #
    # @return - bool

    def odp_integrated?
      @mutex.synchronize { !@api_key.nil? && !@api_host.nil? }
    end
  end
end
