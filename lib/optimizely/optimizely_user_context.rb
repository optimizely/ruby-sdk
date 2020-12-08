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

    attr_reader :user_id, :user_attributes

    def initialize(optimizely_client, user_id, user_attributes)
      @set_attr_mutex = Mutex.new
      @optimizely_client = optimizely_client
      @user_id = user_id
      @user_attributes = user_attributes.nil? ? {} : user_attributes.clone
    end

    # Set an attribute for a given key
    #
    # @param key - An attribute key
    # @param value - An attribute value

    def set_attribute(attribute_key, attribute_value)
      @set_attr_mutex.synchronize { @user_attributes[attribute_key] = attribute_value }
    end

    # Returns a decision result (OptimizelyDecision) for a given flag key and a user context, which contains all data required to deliver the flag.
    #
    # If the SDK finds an error, it’ll return a `decision` with nil for `variation_key`. The decision will include an error message in `reasons`
    #
    # @param key -A flag key for which a decision will be made
    # @param options - A list of options for decision making.
    #
    # @return [OptimizelyDecision] A decision result

    def decide(key, options = nil)
      @optimizely_client&.decide(self, key, options)
    end

    # Returns a hash of decision results (OptimizelyDecision) for multiple flag keys and a user context.
    #
    # If the SDK finds an error for a key, the response will include a decision for the key showing `reasons` for the error.
    # The SDK will always return hash of decisions. When it can not process requests, it’ll return an empty hash after logging the errors.
    #
    # @param keys - A list of flag keys for which the decisions will be made.
    # @param options - A list of options for decision making.
    #
    # @return - Hash of decisions containing flag keys as hash keys and corresponding decisions as their values.

    def decide_for_keys(keys, options = nil)
      @optimizely_client&.decide_for_keys(self, keys, options)
    end

    # Returns a hash of decision results (OptimizelyDecision) for all active flag keys.
    #
    # @param options - A list of options for decision making.
    #
    # @return - Hash of decisions containing flag keys as hash keys and corresponding decisions as their values.

    def decide_all(options = nil)
      @optimizely_client&.decide_all(self, options)
    end

    # Track an event
    #
    # @param event_key - Event key representing the event which needs to be recorded.

    def track_event(event_key, event_tags = nil)
      @optimizely_client&.track(event_key, @user_id, @user_attributes, event_tags)
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
