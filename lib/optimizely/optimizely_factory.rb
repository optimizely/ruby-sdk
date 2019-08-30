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
require 'optimizely/event_dispatcher'
require 'optimizely/event/batch_event_processor'
module Optimizely
  class OptimizelyFactory
    attr_reader :max_event_batch_size, :max_event_flush_interval

    # Convenience method for setting the maximum number of events contained within a batch.
    # @param batch_size Integer - Sets size of EventQueue.
    # @param logger - Optional LoggerInterface Provides a log method to log messages.
    def self.max_event_batch_size(batch_size, logger)
      unless batch_size.is_a? Integer
        logger.log(
          Logger::ERROR,
          'Batch size has invalid type. Reverting to default configuration.'
        )
        return
      end

      unless batch_size.positive?
        logger.log(
          Logger::ERROR,
          'Batch size cannot be <= 0. Reverting to default configuration.'
        )
        return
      end
      @max_event_batch_size = batch_size
    end

    # Convenience method for setting the maximum time interval in milliseconds between event dispatches.
    # @param flush_interval Numeric - Time interval between event dispatches.
    # @param logger - Optional LoggerInterface Provides a log method to log messages.
    def self.max_event_flush_interval(flush_interval, logger)
      unless flush_interval.is_a? Numeric
        logger.log(
          Logger::ERROR,
          'Flush interval has invalid type. Reverting to default configuration.'
        )
        return
      end

      unless flush_interval.positive?
        logger.log(
          Logger::ERROR,
          'Flush interval cannot be <= 0. Reverting to default configuration.'
        )
        return
      end
      @max_event_flush_interval = flush_interval
    end

    # Returns a new optimizely instance.
    #
    # @params sdk_key - Required String uniquely identifying the fallback datafile corresponding to project.
    # @param fallback datafile - Optional JSON string datafile.
    def self.default_instance(sdk_key, datafile = nil)
      Optimizely::Project.new(datafile, nil, nil, nil, nil, nil, sdk_key)
    end

    # Returns a new optimizely instance.
    #
    # @param config_manager - Required ConfigManagerInterface Responds to get_config.
    def self.default_instance_with_config_manager(config_manager)
      Optimizely::Project.new(nil, nil, nil, nil, nil, nil, nil, config_manager)
    end

    # Returns a new optimizely instance.
    #
    # @params sdk_key - Required String uniquely identifying the datafile corresponding to project.
    # @param fallback datafile - Optional JSON string datafile.
    # @param event_dispatcher - Optional EventDispatcherInterface Provides a dispatch_event method which if given a URL and params sends a request to it.
    # @param logger - Optional LoggerInterface Provides a log method to log messages. By default nothing would be logged.
    # @param error_handler - Optional ErrorHandlerInterface which provides a handle_error method to handle exceptions.
    #                 By default all exceptions will be suppressed.
    # @param skip_json_validation - Optional Boolean param to skip JSON schema validation of the provided datafile.
    # @param user_profile_service - Optional UserProfileServiceInterface Provides methods to store and retreive user profiles.
    # @param config_manager - Optional ConfigManagerInterface Responds to get_config.
    # @param notification_center - Optional Instance of NotificationCenter.
    def self.custom_instance(
      sdk_key,
      datafile = nil,
      event_dispatcher = nil,
      logger = nil,
      error_handler = nil,
      skip_json_validation = false,
      user_profile_service = nil,
      config_manager = nil,
      notification_center = nil
    )
      event_processor = BatchEventProcessor.new(
        event_dispatcher: event_dispatcher || EventDispatcher.new,
        batch_size: @max_event_batch_size,
        flush_interval: @max_event_flush_interval,
        notification_center: notification_center
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
        notification_center,
        event_processor
      )
    end
  end
end
