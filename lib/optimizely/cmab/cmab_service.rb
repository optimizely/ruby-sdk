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
require 'optimizely/odp/lru_cache'
require 'optimizely/decide/optimizely_decide_option'
require 'optimizely/logger'
require 'digest'
require 'json'
require 'securerandom'
require 'murmurhash3'

module Optimizely
  CmabDecision = Struct.new(:variation_id, :cmab_uuid, keyword_init: true)
  CmabCacheValue = Struct.new(:attributes_hash, :variation_id, :cmab_uuid, keyword_init: true)

  class DefaultCmabCacheOptions
    # CMAB Constants
    DEFAULT_CMAB_CACHE_TIMEOUT = (30 * 60) # in seconds
    DEFAULT_CMAB_CACHE_SIZE = 1000
  end

  # Default CMAB service implementation
  class DefaultCmabService
    # Initializes a new instance of the CmabService.
    #
    # @param cmab_cache [LRUCache] The cache object used for storing CMAB data. Must be an instance of LRUCache.
    # @param cmab_client [DefaultCmabClient] The client used to interact with the CMAB service. Must be an instance of DefaultCmabClient.
    # @param logger [Logger, nil] Optional logger for logging messages. Defaults to nil.
    #
    # @raise [ArgumentError] If cmab_cache is not an instance of LRUCache.
    # @raise [ArgumentError] If cmab_client is not an instance of DefaultCmabClient.

    NUM_LOCK_STRIPES = 1000

    def initialize(cmab_cache, cmab_client, logger = nil)
      @cmab_cache = cmab_cache
      @cmab_client = cmab_client
      @logger = logger || NoOpLogger.new
      @locks = Array.new(NUM_LOCK_STRIPES) { Mutex.new }
    end

    def get_decision(project_config, user_context, rule_id, options)
      lock_index = get_lock_index(user_context.user_id, rule_id)

      @locks[lock_index].synchronize do
        get_decision_impl(project_config, user_context, rule_id, options)
      end
    end

    private

    def get_lock_index(user_id, rule_id)
      # Create a hash of user_id + rule_id for consistent lock selection
      hash_input = "#{user_id}#{rule_id}"
      hash_value = MurmurHash3::V32.str_hash(hash_input, 1) & 0xFFFFFFFF # Convert to unsigned 32-bit equivalent
      hash_value % NUM_LOCK_STRIPES
    end

    def get_decision_impl(project_config, user_context, rule_id, options)
      # Retrieves a decision for a given user and rule, utilizing a cache for efficiency.
      #
      # This method filters user attributes, checks for various cache-related options,
      # and either fetches a fresh decision or returns a cached one if appropriate.
      # It supports options to ignore the cache, reset the cache, or invalidate a specific user's cache entry.
      #
      # @param project_config [Object] The project configuration object.
      # @param user_context [Object] The user context containing user_id and attributes.
      # @param rule_id [String] The identifier for the decision rule.
      # @param options [Array<Symbol>, nil] Optional flags to control cache behavior. Supported options:
      #   - OptimizelyDecideOption::IGNORE_CMAB_CACHE: Bypass cache and fetch a new decision.
      #   - OptimizelyDecideOption::RESET_CMAB_CACHE: Reset the entire cache.
      #   - OptimizelyDecideOption::INVALIDATE_USER_CMAB_CACHE: Invalidate cache for the specific user and rule.
      #
      # @return [CmabDecision] The decision object containing variation_id and cmab_uuid.

      filtered_attributes = filter_attributes(project_config, user_context, rule_id)
      reasons = []

      if options&.include?(Decide::OptimizelyDecideOption::IGNORE_CMAB_CACHE)
        reason = "Ignoring CMAB cache for user '#{user_context.user_id}' and rule '#{rule_id}'"
        @logger.log(Logger::DEBUG, reason)
        reasons << reason
        cmab_decision = fetch_decision(rule_id, user_context.user_id, filtered_attributes)
        return [cmab_decision, reasons]
      end

      if options&.include?(Decide::OptimizelyDecideOption::RESET_CMAB_CACHE)
        reason = "Resetting CMAB cache for user '#{user_context.user_id}' and rule '#{rule_id}'"
        @logger.log(Logger::DEBUG, reason)
        reasons << reason
        @cmab_cache.reset
      end

      cache_key = get_cache_key(user_context.user_id, rule_id)

      if options&.include?(Decide::OptimizelyDecideOption::INVALIDATE_USER_CMAB_CACHE)
        reason = "Invalidating CMAB cache for user '#{user_context.user_id}' and rule '#{rule_id}'"
        @logger.log(Logger::DEBUG, reason)
        reasons << reason
        @cmab_cache.remove(cache_key)
      end

      cached_value = @cmab_cache.lookup(cache_key)
      attributes_hash = hash_attributes(filtered_attributes)

      if cached_value
        if cached_value.attributes_hash == attributes_hash
          reason = "CMAB cache hit for user '#{user_context.user_id}' and rule '#{rule_id}'"
          @logger.log(Logger::DEBUG, reason)
          reasons << reason
          return [CmabDecision.new(variation_id: cached_value.variation_id, cmab_uuid: cached_value.cmab_uuid), reasons]
        else
          reason = "CMAB cache attributes mismatch for user '#{user_context.user_id}' and rule '#{rule_id}', fetching new decision."
          @logger.log(Logger::DEBUG, reason)
          reasons << reason
          @cmab_cache.remove(cache_key)
        end
      else
        reason = "CMAB cache miss for user '#{user_context.user_id}' and rule '#{rule_id}'"
        @logger.log(Logger::DEBUG, reason)
        reasons << reason
      end

      cmab_decision = fetch_decision(rule_id, user_context.user_id, filtered_attributes)
      reason = "CMAB decision is #{cmab_decision.to_h}"
      @logger.log(Logger::DEBUG, reason)
      reasons << reason

      @cmab_cache.save(cache_key,
                       CmabCacheValue.new(
                         attributes_hash: attributes_hash,
                         variation_id: cmab_decision.variation_id,
                         cmab_uuid: cmab_decision.cmab_uuid
                       ))
      [cmab_decision, reasons]
    end

    def fetch_decision(rule_id, user_id, attributes)
      # Fetches a decision for a given rule and user, along with user attributes.
      #
      # Generates a unique UUID for the decision request, then delegates to the CMAB client
      # to fetch the variation ID. Returns a CmabDecision object containing the variation ID
      # and the generated UUID.
      #
      # @param rule_id [String] The identifier for the rule to evaluate.
      # @param user_id [String] The identifier for the user.
      # @param attributes [Hash] A hash of user attributes to be used in decision making.
      # @return [CmabDecision] The decision object containing the variation ID and UUID.
      cmab_uuid = SecureRandom.uuid
      variation_id = @cmab_client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      CmabDecision.new(variation_id: variation_id, cmab_uuid: cmab_uuid)
    end

    def filter_attributes(project_config, user_context, rule_id)
      # Filters the user attributes based on the CMAB attribute IDs defined in the experiment.
      #
      # @param project_config [Object] The project configuration object containing experiment and attribute mappings.
      # @param user_context [Object] The user context object containing user attributes.
      # @param rule_id [String] The ID of the experiment (rule) to filter attributes for.
      # @return [Hash] A hash of filtered user attributes whose keys match the CMAB attribute IDs for the given experiment.
      user_attributes = user_context.user_attributes
      filtered_user_attributes = {}

      experiment = project_config.experiment_id_map[rule_id]
      return filtered_user_attributes if experiment.nil? || experiment['cmab'].nil?

      cmab_attribute_ids = experiment['cmab']['attributeIds']
      cmab_attribute_ids.each do |attribute_id|
        attribute = project_config.attribute_id_map[attribute_id]
        next unless attribute

        attribute_key = attribute['key']
        filtered_user_attributes[attribute_key] = user_attributes[attribute_key] if user_attributes.key?(attribute_key)
      end

      filtered_user_attributes
    end

    def get_cache_key(user_id, rule_id)
      # Generates a cache key string based on the provided user ID and rule ID.
      #
      # The cache key is constructed in the format: "<user_id_length>-<user_id>-<rule_id>",
      # where <user_id_length> is the length of the user_id string.
      #
      # @param user_id [String] The unique identifier for the user.
      # @param rule_id [String] The unique identifier for the rule.
      # @return [String] The generated cache key.
      "#{user_id.length}-#{user_id}-#{rule_id}"
    end

    def hash_attributes(attributes)
      # Generates an MD5 hash for a given attributes hash.
      #
      # The method sorts the attributes by key, serializes them to a JSON string,
      # and then computes the MD5 hash of the resulting string. This ensures that
      # the hash is consistent regardless of the original key order in the input hash.
      #
      # @param attributes [Hash] The attributes to be hashed.
      # @return [String] The MD5 hash of the sorted and serialized attributes.
      sorted_attrs = JSON.generate(attributes.sort.to_h)
      Digest::MD5.hexdigest(sorted_attrs)
    end
  end
end
