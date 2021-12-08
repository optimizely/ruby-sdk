# frozen_string_literal: true

#
#    Copyright 2020, Optimizely and contributors
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
  class OptimizelyUserContext
    # Representation of an Optimizely User Context using which APIs are to be called.

    attr_reader :user_id
    attr_reader :forced_decisions
    attr_reader :OptimizelyDecisionContext
    attr_reader :OptimizelyForcedDecision

    OptimizelyDecisionContext = Struct.new(:flag_key, :rule_key)
    OptimizelyForcedDecision = Struct.new(:variation_key)
    def initialize(optimizely_client, user_id, user_attributes)
      @attr_mutex = Mutex.new
      @forced_decision_mutex = Mutex.new
      @optimizely_client = optimizely_client
      @user_id = user_id
      @user_attributes = user_attributes.nil? ? {} : user_attributes.clone
      @forced_decisions = {}
    end

    def clone
      user_context = OptimizelyUserContext.new(@optimizely_client, @user_id, user_attributes)
      @forced_decision_mutex.synchronize { user_context.instance_variable_set('@forced_decisions', @forced_decisions.dup) unless @forced_decisions.empty? }
      user_context
    end

    def user_attributes
      @attr_mutex.synchronize { @user_attributes.clone }
    end

    # Set an attribute for a given key
    #
    # @param key - An attribute key
    # @param value - An attribute value

    def set_attribute(attribute_key, attribute_value)
      @attr_mutex.synchronize { @user_attributes[attribute_key] = attribute_value }
    end

    # Returns a decision result (OptimizelyDecision) for a given flag key and a user context, which contains all data required to deliver the flag.
    #
    # If the SDK finds an error, it'll return a `decision` with nil for `variation_key`. The decision will include an error message in `reasons`
    #
    # @param key -A flag key for which a decision will be made
    # @param options - A list of options for decision making.
    #
    # @return [OptimizelyDecision] A decision result

    def decide(key, options = nil)
      @optimizely_client&.decide(clone, key, options)
    end

    # Returns a hash of decision results (OptimizelyDecision) for multiple flag keys and a user context.
    #
    # If the SDK finds an error for a key, the response will include a decision for the key showing `reasons` for the error.
    # The SDK will always return hash of decisions. When it can not process requests, it'll return an empty hash after logging the errors.
    #
    # @param keys - A list of flag keys for which the decisions will be made.
    # @param options - A list of options for decision making.
    #
    # @return - Hash of decisions containing flag keys as hash keys and corresponding decisions as their values.

    def decide_for_keys(keys, options = nil)
      @optimizely_client&.decide_for_keys(clone, keys, options)
    end

    # Returns a hash of decision results (OptimizelyDecision) for all active flag keys.
    #
    # @param options - A list of options for decision making.
    #
    # @return - Hash of decisions containing flag keys as hash keys and corresponding decisions as their values.

    def decide_all(options = nil)
      @optimizely_client&.decide_all(clone, options)
    end

    # Sets the forced decision (variation key) for a given flag and an optional rule.
    #
    # @param context - An OptimizelyDecisionContext object containg flag key and rule key.
    # @param decision - An OptimizelyForcedDecision object containing variation key
    #
    # @return - true if the forced decision has been set successfully.

    def set_forced_decision(context, decision)
      flag_key = context[:flag_key]
      return false if flag_key.nil?

      @forced_decision_mutex.synchronize { @forced_decisions[context] = decision }

      true
    end

    def find_forced_decision(context)
      return nil if @forced_decisions.empty?

      decision = nil
      @forced_decision_mutex.synchronize { decision = @forced_decisions[context] }
      decision
    end

    # Returns the forced decision for a given flag and an optional rule.
    #
    # @param context - An OptimizelyDecisionContext object containg flag key and rule key.
    #
    # @return - A variation key or nil if forced decisions are not set for the parameters.

    def get_forced_decision(context)
      find_forced_decision(context)
    end

    # Removes the forced decision for a given flag and an optional rule.
    #
    # @param context - An OptimizelyDecisionContext object containg flag key and rule key.
    #
    # @return - true if the forced decision has been removed successfully.

    def remove_forced_decision(context)
      deleted = false
      @forced_decision_mutex.synchronize do
        if @forced_decisions.key?(context)
          @forced_decisions.delete(context)
          deleted = true
        end
      end
      deleted
    end

    # Removes all forced decisions bound to this user context.
    #
    # @return - true if forced decisions have been removed successfully.

    def remove_all_forced_decisions
      return false if @optimizely_client&.get_optimizely_config.nil?

      @forced_decision_mutex.synchronize { @forced_decisions.clear }
      true
    end

    def find_validated_forced_decision(context)
      decision = find_forced_decision(context)
      flag_key = context[:flag_key]
      rule_key = context[:rule_key]
      variation_key = decision ? decision[:variation_key] : decision
      reasons = []
      target = rule_key ? "flag (#{flag_key}), rule (#{rule_key})" : "flag (#{flag_key})"
      if variation_key
        variation = @optimizely_client.get_flag_variation_by_key(flag_key, variation_key)
        if variation
          reason = "Variation (#{variation_key}) is mapped to #{target} and user (#{@user_id}) in the forced decision map."
          reasons.push(reason)
          return variation, reasons
        else
          reason = "Invalid variation is mapped to #{target} and user (#{@user_id}) in the forced decision map."
          reasons.push(reason)
        end
      end

      [nil, reasons]
    end

    # Track an event
    #
    # @param event_key - Event key representing the event which needs to be recorded.

    def track_event(event_key, event_tags = nil)
      @optimizely_client&.track(event_key, @user_id, user_attributes, event_tags)
    end

    def as_json
      {
        user_id: @user_id,
        attributes: @user_attributes
      }
    end

    def to_json(*args)
      as_json.to_json(*args)
    end
  end
end
