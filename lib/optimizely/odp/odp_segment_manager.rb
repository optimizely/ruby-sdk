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
require_relative 'odp_segment_api_manager'

module Optimizely
  class OdpSegmentManager
    # Schedules connections to ODP for audience segmentation and caches the results
    attr_accessor :odp_config
    attr_reader :segments_cache, :api_manager, :logger

    def initialize(segments_cache, api_manager = nil, logger = nil, proxy_config = nil)
      @odp_config = nil
      @logger = logger || NoOpLogger.new
      @api_manager = api_manager || OdpSegmentApiManager.new(logger: @logger, proxy_config: proxy_config)
      @segments_cache = segments_cache
    end

    # Returns qualified segments for the user from the cache or the ODP server if not in the cache.
    #
    # @param user_key - The key for identifying the id type.
    # @param user_value - The id itself.
    # @param options - An array of OptimizelySegmentOptions used to ignore and/or reset the cache.
    #
    # @return - Array of qualified segments.
    def fetch_qualified_segments(user_key, user_value, options)
      odp_api_key = @odp_config&.api_key
      odp_api_host = @odp_config&.api_host
      segments_to_check = @odp_config&.segments_to_check

      if odp_api_key.nil? || odp_api_host.nil?
        @logger.log(Logger::ERROR, format(Optimizely::Helpers::Constants::ODP_LOGS[:FETCH_SEGMENTS_FAILED], 'ODP is not enabled'))
        return nil
      end

      unless segments_to_check&.size&.positive?
        @logger.log(Logger::DEBUG, 'No segments are used in the project. Returning empty list')
        return []
      end

      cache_key = make_cache_key(user_key, user_value)

      ignore_cache = options.include?(OptimizelySegmentOption::IGNORE_CACHE)
      reset_cache = options.include?(OptimizelySegmentOption::RESET_CACHE)

      reset if reset_cache

      unless ignore_cache || reset_cache
        segments = @segments_cache.lookup(cache_key)
        unless segments.nil?
          @logger.log(Logger::DEBUG, 'ODP cache hit. Returning segments from cache.')
          return segments
        end
        @logger.log(Logger::DEBUG, 'ODP cache miss.')
      end

      @logger.log(Logger::DEBUG, 'Making a call to ODP server.')

      segments = @api_manager.fetch_segments(odp_api_key, odp_api_host, user_key, user_value, segments_to_check)
      @segments_cache.save(cache_key, segments) unless segments.nil? || ignore_cache
      segments
    end

    def reset
      @segments_cache.reset
      nil
    end

    private

    def make_cache_key(user_key, user_value)
      "#{user_key}-$-#{user_value}"
    end
  end

  class OptimizelySegmentOption
    # Options for the OdpSegmentManager
    IGNORE_CACHE = :IGNORE_CACHE
    RESET_CACHE = :RESET_CACHE
  end
end
