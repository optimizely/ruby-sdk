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

module Optimizely
  class LRUCache
    # Least Recently Used cache that invalidates entries older than the timeout.

    attr_reader :capacity, :timeout

    def initialize(capacity, timeout_in_secs)
      # @param capacity - The max size of the cache. If set <= 0, caching is disabled.
      # @param timeout_in_secs - Seconds until a cache item is considered stale.
      #                          If set <= 0, items never expire.
      @cache_mutex = Mutex.new
      @map = {}
      @capacity = capacity
      @timeout = timeout_in_secs
    end

    # Retrieve the non stale value from the cache corresponding to the provided key
    # or nil if key is not found
    # Moves the key/value pair to the end of the cache
    #
    # @param key - The key to retrieve

    def lookup(key)
      return nil if @capacity <= 0

      @cache_mutex.synchronize do
        return nil unless @map.include?(key)

        element = @map.delete(key)
        return nil if element.stale?(@timeout)

        @map[key] = element

        element.value
      end
    end

    # Save a key/value pair into the cache
    # Moves the key/value pair to the end of the cache
    #
    # @param key - A user key
    # @param value - A user value

    def save(key, value)
      return if @capacity <= 0

      @cache_mutex.synchronize do
        @map.delete(key) if @map.key?(key)

        @map[key] = CacheElement.new(value)

        @map.delete(@map.first[0]) if @map.size > @capacity
        nil
      end
    end

    # Clears the cache

    def reset
      return if @capacity <= 0

      @cache_mutex.synchronize { @map.clear }
      nil
    end

    # Retrieve a value from the cache for a given key or nil if key is not found
    # Doesn't update the cache
    #
    # @param key - The key to retrieve

    def peek(key)
      return nil if @capacity <= 0

      @cache_mutex.synchronize { @map[key]&.value }
    end
  end

  class CacheElement
    # Individual element for the LRUCache.
    attr_reader :value, :timestamp

    def initialize(value)
      @value = value
      @timestamp = Time.new
    end

    def stale?(timeout)
      # Returns true if the provided timeout has passed since the element's timestamp.
      #
      # @param timeout - The duration to check against
      return false if timeout <= 0

      Time.new - @timestamp >= timeout
    end
  end
end
