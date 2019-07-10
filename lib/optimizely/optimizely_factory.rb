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

require 'optimizely'
module Optimizely
  class OptimizelyFactory
    def self.initialize(
      datafile = nil,
      event_dispatcher = nil,
      logger = nil,
      error_handler = nil,
      skip_json_validation = false,
      user_profile_service = nil,
      sdk_key = nil,
      config_manager = nil,
      notification_center = nil
    )
      Optimizely::Project.new(
        datafile,
        event_dispatcher,
        logger,
        error_handler,
        skip_json_validation,
        user_profile_service,
        sdk_key,
        config_manager,
        notification_center
      )
    end

    def self.initialize_optimizely_with_sdk_key(
      datafile = nil,
      logger = nil,
      event_dispatcher = nil,
      error_handler = nil,
      skip_json_validation = false,
      user_profile_service = nil,
      sdk_key = nil,
      notification_center = nil
    )
      Optimizely::Project.new(
        datafile,
        event_dispatcher,
        logger,
        error_handler,
        skip_json_validation,
        user_profile_service,
        sdk_key,
        nil,
        notification_center
      )
    end

    def self.initialize_optimizely_with_config_manager(
      datafile = nil,
      event_dispatcher = nil,
      logger = nil,
      error_handler = nil,
      skip_json_validation = false,
      user_profile_service = nil,
      config_manager = nil,
      notification_center = nil
    )
      Optimizely::Project.new(
        datafile,
        event_dispatcher,
        logger,
        error_handler,
        skip_json_validation,
        user_profile_service,
        nil,
        config_manager,
        notification_center
      )
    end
  end
end
