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
require_relative 'zaius_graphql_api_manager'

module Optimizely
  class OdpSegmentManager
    # Schedules connections to ODP for audience segmentation and caches the results
    attr_reader :odp_config, :segments_cache, :zaius_manager, :logger

    def initialize(cache_size, cache_timeout_in_secs, odp_config, api_manager = nil, logger = nil, proxy_config = nil)
      @odp_config = odp_config
      @logger = logger || NoOpLogger.new
      @zaius_manager = api_manager || ZaiusGraphQLApiManager.new(logger: @logger, proxy_config: proxy_config)
      @segments_cache = Optimizely::LRUCache.new(cache_size, cache_timeout_in_secs)
    end

    def fetch_qualified_segments(segment_request)
      odp_api_key = @odp_config&.api_key
      odp_api_host = @odp_config&.api_host

      unless odp_api_host && odp_api_key
        @logger.log(Logger::ERROR, 'api_key/api_host not defined')
        segment_request.segments = nil
        return
      end
      segments_to_check = @odp_config&.segments_to_check

      unless segments_to_check&.size&.positive?
        segment_request.segments = []
        return
      end

      cache_key = make_cache_key(segment_request.user_key, segment_request.user_value)

      ignore_cache = segment_request.options.include?(OptimizelySegmentOption::IGNORE_CACHE)
      reset_cache = segment_request.options.include?(OptimizelySegmentOption::RESET_CACHE)

      reset if reset_cache

      unless ignore_cache || reset_cache
        segments = @segments_cache.lookup(cache_key)
        unless segments.nil?
          segment_request.segments = segments
          return
        end
      end

      Thread.new do
        segments = @zaius_manager.fetch_segments(odp_api_key, odp_api_host, segment_request.user_key, segment_request.user_value, segments_to_check)
        @segments_cache.save(cache_key, segments) unless segments.nil? || ignore_cache
        segment_request.segments = segments
      end

      nil
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
    IGNORE_CACHE = :IGNORE_CACHE
    RESET_CACHE = :RESET_CACHE
  end

  class OdpSegmentRequest
    # Allows asynchronous communication between OptimizelyUserContext and OdpSegmentManger
    attr_reader :user_key, :user_value, :options

    def initialize(user_key, user_value, options)
      @user_key = user_key
      @user_value = user_value
      @options = options
      @queue = Thread::SizedQueue.new(1)
      @segments = nil
    end

    # If this method is called without a corresponding call to segments=, it will wait indefinitely
    def wait_for_segments
      return @segments if @queue.closed?

      @segments = @queue.pop
      @queue.close
      @segments
    end

    def segments=(segments)
      if @queue.closed?
        @segments = segments
        return
      end
      @queue.push(segments, non_block: true)
    end
  end
end
