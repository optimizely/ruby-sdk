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

require_relative 'constants'

module Optimizely
  module Helpers
    class OptimizelySdkSettings
      attr_accessor :odp_disabled, :segments_cache_size, :segments_cache_timeout_in_secs, :odp_segments_cache, :odp_segment_manager, :odp_event_manager, :fetch_segments_timeout

      # Contains configuration used for Optimizely Project initialization.
      #
      # @param disable_odp - Set this flag to true (default = false) to disable ODP features.
      # @param segments_cache_size - The maximum size of audience segments cache (optional. default = 10,000). Set to zero to disable caching.
      # @param segments_cache_timeout_in_secs - The timeout in seconds of audience segments cache (optional. default = 600). Set to zero to disable timeout.
      # @param odp_segments_cache - A custom odp segments cache. Required methods include: `save(key, value)`, `lookup(key) -> value`, and `reset()`
      # @param odp_segment_manager - A custom odp segment manager. Required method is: `fetch_qualified_segments(user_key, user_value, options)`.
      # @param odp_event_manager - A custom odp event manager. Required method is: `send_event(type:, action:, identifiers:, data:)`
      # @param fetch_segments_timeout - The timeout in seconds of to fetch odp segments (optional. default = 10).
      def initialize(
        disable_odp: false,
        segments_cache_size: Constants::ODP_SEGMENTS_CACHE_CONFIG[:DEFAULT_CAPACITY],
        segments_cache_timeout_in_secs: Constants::ODP_SEGMENTS_CACHE_CONFIG[:DEFAULT_TIMEOUT_SECONDS],
        odp_segments_cache: nil,
        odp_segment_manager: nil,
        odp_event_manager: nil,
        fetch_segments_timeout: nil
        odp_event_timeout: nil
      )
        @odp_disabled = disable_odp
        @segments_cache_size = segments_cache_size
        @segments_cache_timeout_in_secs = segments_cache_timeout_in_secs
        @odp_segments_cache = odp_segments_cache
        @odp_segment_manager = odp_segment_manager
        @odp_event_manager = odp_event_manager
        @fetch_segments_timeout = fetch_segments_timeout
        @odp_event_timeout = odp_event_timeout
      end
    end
  end
end
