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

require 'json'
require_relative '../helpers/constants'

module Optimizely
  class OdpEvent
    # Representation of an odp event which can be sent to the Optimizely odp platform.

    KEY_FOR_USER_ID = Helpers::Constants::ODP_MANAGER_CONFIG[:KEY_FOR_USER_ID]

    def initialize(type:, action:, identifiers:, data:)
      @type = type
      @action = action
      @identifiers = convert_identifiers(identifiers)
      @data = add_common_event_data(data)
    end

    def add_common_event_data(custom_data)
      data = {
        idempotence_id: SecureRandom.uuid,
        data_source_type: 'sdk',
        data_source: 'ruby-sdk',
        data_source_version: VERSION
      }
      data.update(custom_data)
      data
    end

    def convert_identifiers(identifiers)
      # Convert incorrect case/separator of identifier key `fs_user_id`
      # (ie. `fs-user-id`, `FS_USER_ID`).

      identifiers.clone.each_key do |key|
        break if key == KEY_FOR_USER_ID

        if ['fs-user-id', KEY_FOR_USER_ID].include?(key.downcase)
          identifiers[KEY_FOR_USER_ID] = identifiers.delete(key)
          break
        end
      end

      identifiers
    end

    def to_json(*_args)
      {
        type: @type,
        action: @action,
        identifiers: @identifiers,
        data: @data
      }.to_json
    end

    def ==(other)
      to_json == other.to_json
    end
  end
end
