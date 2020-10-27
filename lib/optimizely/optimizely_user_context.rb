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
      @optimizely_client = optimizely_client
      @user_id = user_id
      @user_attributes = user_attributes

      @user_attributes = {} if @user_attributes.nil?
    end

    def set_attribute(attribute_key, attribute_value)
      @user_attributes[attribute_key] = attribute_value
    end

    def decide(key, options = nil)
      @optimizely_client.decide(self, key, options)
    end

    def decide_for_keys(keys, options = nil)
      # TODO: call decideForKeys in Optimizely class.
    end

    def decide_all(options = nil)
      # TODO: call decideForAll in optimizely class.
    end

    def track_event(event_key, event_tags = nil)
      @optimizely_client.track(event_key, @user_id, @user_attributes, event_tags)
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
