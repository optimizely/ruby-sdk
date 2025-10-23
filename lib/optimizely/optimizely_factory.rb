# frozen_string_literal: true

#
#    Copyright 2019, 2022-2023, Optimizely and contributors
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
require 'optimizely/error_handler'
require 'optimizely/event_dispatcher'
require 'optimizely/event/batch_event_processor'
require 'optimizely/logger'
require 'optimizely/notification_center'
require 'optimizely/cmab/cmab_client'
require 'optimizely/cmab/cmab_service'

module Optimizely
  class OptimizelyFactory
    # Convenience method for setting the maximum number of events contained within a batch.
    # @param batch_size Integer - Sets size of EventQueue.
    # @param logger - Optional LoggerInterface Provides a log method to log messages.
    def self.max_event_batch_size(batch_size, logger = NoOpLogger.new)
      unless batch_size.is_a? Integer
        logger.log(
          Logger::ERROR,
          "Batch size is invalid, setting to default batch size #{BatchEventProcessor::DEFAULT_BATCH_SIZE}."
        )
        return
      end

      unless batch_size.positive?
        logger.log(
          Logger::ERROR,
          "Batch size is negative, setting to default batch size #{BatchEventProcessor::DEFAULT_BATCH_SIZE}."
        )
        return
      end
      @max_event_batch_size = batch_size
    end

    # Convenience method for setting the maximum time interval in milliseconds between event dispatches.
    # @param flush_interval Numeric - Time interval between event dispatches.
    # @param logger - Optional LoggerInterface Provides a log method to log messages.
    def self.max_event_flush_interval(flush_interval, logger = NoOpLogger.new)
      unless flush_interval.is_a? Numeric
        logger.log(
          Logger::ERROR,
          "Flush interval is invalid, setting to default flush interval #{BatchEventProcessor::DEFAULT_BATCH_INTERVAL}."
        )
        return
      end

      unless flush_interval.positive?
        logger.log(
          Logger::ERROR,
          "Flush interval is negative, setting to default flush interval #{BatchEventProcessor::DEFAULT_BATCH_INTERVAL}."
        )
        return
      end
      @max_event_flush_interval = flush_interval
    end

    # Convenience method for setting frequency at which datafile has to be polled and ProjectConfig updated.
    #
    # @param polling_interval Numeric - Time in seconds after which to update datafile.
    def self.polling_interval(polling_interval)
      @polling_interval = polling_interval
    end

    # Convenience method for setting timeout to block the config call until config has been initialized.
    #
    # @param blocking_timeout Numeric - Time in seconds.
    def self.blocking_timeout(blocking_timeout)
      @blocking_timeout = blocking_timeout
    end

    # Convenience method for setting CMAB cache size.
    # @param cache_size Integer - Maximum number of items in CMAB cache.
    # @param logger - Optional LoggerInterface Provides a log method to log messages.
    def self.cmab_cache_size(cache_size, logger = NoOpLogger.new)
      unless cache_size.is_a?(Integer) && cache_size.positive?
        logger.log(
          Logger::ERROR,
          "CMAB cache size is invalid, setting to default size #{Optimizely::DefaultCmabCacheOptions::DEFAULT_CMAB_CACHE_SIZE}."
        )
        return
      end
      @cmab_cache_size = cache_size
    end

    # Convenience method for setting CMAB cache TTL.
    # @param cache_ttl Numeric - Time in seconds for cache entries to live.
    # @param logger - Optional LoggerInterface Provides a log method to log messages.
    def self.cmab_cache_ttl(cache_ttl, logger = NoOpLogger.new)
      unless cache_ttl.is_a?(Numeric) && cache_ttl.positive?
        logger.log(
          Logger::ERROR,
          "CMAB cache TTL is invalid, setting to default TTL #{Optimizely::DefaultCmabCacheOptions::DEFAULT_CMAB_CACHE_TIMEOUT}."
        )
        return
      end
      @cmab_cache_ttl = cache_ttl
    end

    # Convenience method for setting custom CMAB cache.
    # @param custom_cache - Cache implementation responding to lookup, save, remove, and reset methods.
    def self.cmab_custom_cache(custom_cache)
      @cmab_custom_cache = custom_cache
    end

    # Returns a new optimizely instance.
    #
    # @params sdk_key - Required String uniquely identifying the fallback datafile corresponding to project.
    # @param fallback datafile - Optional JSON string datafile.
    def self.default_instance(sdk_key, datafile = nil)
      error_handler = NoOpErrorHandler.new
      logger = NoOpLogger.new
      notification_center = NotificationCenter.new(logger, error_handler)

      config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: sdk_key,
        polling_interval: @polling_interval,
        blocking_timeout: @blocking_timeout,
        datafile: datafile,
        logger: logger,
        error_handler: error_handler,
        notification_center: notification_center
      )

      Optimizely::Project.new(
        datafile: datafile, logger: logger, error_handler: error_handler, sdk_key: sdk_key, config_manager: config_manager, notification_center: notification_center
      )
    end

    # Returns a new optimizely instance.
    #
    # @param config_manager - Required ConfigManagerInterface Responds to 'config' method.
    def self.default_instance_with_config_manager(config_manager)
      Optimizely::Project.new(config_manager: config_manager)
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
    # @param config_manager - Optional ConfigManagerInterface Responds to 'config' method.
    # @param notification_center - Optional Instance of NotificationCenter.
    # @param settings: Optional instance of OptimizelySdkSettings for sdk configuration.
    #
    # if @max_event_batch_size and @max_event_flush_interval are nil then default batchsize and flush_interval
    # will be used to setup batchEventProcessor.
    def self.custom_instance( # rubocop:disable Metrics/ParameterLists
      sdk_key,
      datafile = nil,
      event_dispatcher = nil,
      logger = nil,
      error_handler = nil,
      skip_json_validation = false, # rubocop:disable Style/OptionalBooleanParameter
      user_profile_service = nil,
      config_manager = nil,
      notification_center = nil,
      settings = nil
    )
      error_handler ||= NoOpErrorHandler.new
      logger ||= NoOpLogger.new
      notification_center = notification_center.is_a?(Optimizely::NotificationCenter) ? notification_center : NotificationCenter.new(logger, error_handler)

      event_processor = BatchEventProcessor.new(
        event_dispatcher: event_dispatcher || EventDispatcher.new,
        batch_size: @max_event_batch_size,
        flush_interval: @max_event_flush_interval,
        logger: logger,
        notification_center: notification_center
      )

      config_manager ||= Optimizely::HTTPProjectConfigManager.new(
        sdk_key: sdk_key,
        polling_interval: @polling_interval,
        blocking_timeout: @blocking_timeout,
        datafile: datafile,
        logger: logger,
        error_handler: error_handler,
        skip_json_validation: skip_json_validation,
        notification_center: notification_center
      )

      # Initialize CMAB components
      cmab_client = DefaultCmabClient.new(logger: logger)
      cmab_cache = @cmab_custom_cache || LRUCache.new(
        @cmab_cache_size || Optimizely::DefaultCmabCacheOptions::DEFAULT_CMAB_CACHE_SIZE,
        @cmab_cache_ttl || Optimizely::DefaultCmabCacheOptions::DEFAULT_CMAB_CACHE_TIMEOUT
      )
      cmab_service = DefaultCmabService.new(cmab_cache, cmab_client, logger)

      Optimizely::Project.new(
        datafile: datafile,
        event_dispatcher: event_dispatcher,
        logger: logger,
        error_handler: error_handler,
        skip_json_validation: skip_json_validation,
        user_profile_service: user_profile_service,
        sdk_key: sdk_key,
        config_manager: config_manager,
        notification_center: notification_center,
        event_processor: event_processor,
        settings: settings,
        cmab_service: cmab_service
      )
    end
  end
end
