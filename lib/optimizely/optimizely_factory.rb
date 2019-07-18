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
    # Returns a new optimizely instance.
    #
    # @params sdk_key - Required String uniquely identifying the fallback datafile corresponding to project.
    # @param fallback - Optional JSON string datafile.
    def self.default_instance(sdk_key, fallback = nil)
      Optimizely::Project.new(fallback, nil, nil, nil, nil, nil, sdk_key)
    end

    # Returns a new optimizely instance.
    #
    # @param config_manager - Required ConfigManagerInterface Responds to get_config.
    def self.default_instance_with_manager(config_manager)
      Optimizely::Project.new(nil, nil, nil, nil, nil, nil, nil, config_manager)
    end

    # Returns a new optimizely instance.
    #
    # @params sdk_key - Required String uniquely identifying the datafile corresponding to project.
    # @param fallback - Optional JSON string datafile.
    # @param event_dispatcher - Optional EventDispatcherInterface Provides a dispatch_event method which if given a URL and params sends a request to it.
    # @param logger - Optional LoggerInterface Provides a log method to log messages. By default nothing would be logged.
    # @param error_handler - Optional ErrorHandlerInterface which provides a handle_error method to handle exceptions.
    #                 By default all exceptions will be suppressed.
    # @param skip_json_validation - Optional Boolean param to skip JSON schema validation of the provided datafile.
    # @param user_profile_service - Optional UserProfileServiceInterface Provides methods to store and retreive user profiles.
    # @param notification_center - Optional Instance of NotificationCenter.
    def self.custom_instance(
      sdk_key,
      fallback = nil,
      event_dispatcher = nil,
      logger = nil,
      error_handler = nil,
      skip_json_validation = false,
      user_profile_service = nil,
      notification_center = nil
    )
      Optimizely::Project.new(
        fallback,
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

    # Returns a new optimizely instance.
    #
    # @param config_manager - Required ConfigManagerInterface Responds to get_config.
    # @param event_dispatcher - Optional EventDispatcherInterface Provides a dispatch_event method which if given a URL and params sends a request to it.
    # @param logger - Optional LoggerInterface which provides a log method to log messages. By default nothing would be logged.
    # @param error_handler - Optional ErrorHandlerInterface which provides a handle_error method to handle exceptions.
    #                 By default all exceptions will be suppressed.
    # @param user_profile_service - Optional UserProfileServiceInterface which provides methods to store and retreive user profiles.
    # @param skip_json_validation - Optional Boolean param to skip JSON schema validation of the provided datafile.
    # @param notification_center - Optional Instance of NotificationCenter.
    def self.custom_instance_with_manager(
      config_manager,
      event_dispatcher = nil,
      logger = nil,
      error_handler = nil,
      skip_json_validation = false,
      user_profile_service = nil,
      notification_center = nil
    )
      Optimizely::Project.new(
        nil,
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
