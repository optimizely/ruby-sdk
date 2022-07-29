# frozen_string_literal: true

#
#    Copyright 2019, Optimizely and contributors
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
  class VisitorAttribute
    attr_reader :entity_id, :key, :type, :value

    def initialize(entity_id:, key:, type:, value:)
      @entity_id = entity_id
      @key = key
      @type = type
      @value = value
    end

    def as_json
      {
        entity_id: @entity_id,
        key: @key,
        type: @type,
        value: @value
      }
    end
  end
end
