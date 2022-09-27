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

require 'optimizely/logger'
require_relative '../helpers/constants'
require_relative '../helpers/validator'
require_relative '../exceptions'
require_relative 'odp_config'
require_relative 'lru_cache'
require_relative 'odp_segment_manager'
require_relative 'odp_event_manager'

module Optimizely
  class OdpManager
    ODP_LOGS = Helpers::Constants::ODP_LOGS
    ODP_MANAGER_CONFIG = Helpers::Constants::ODP_MANAGER_CONFIG
    ODP_CONFIG_STATE = Helpers::Constants::ODP_CONFIG_STATE

    def initialize(disable:, segments_cache: nil, segment_manager: nil, event_manager: nil, logger: nil)
      @enabled = !disable
      @segment_manager = segment_manager
      @event_manager = event_manager
      @logger = logger || NoOpLogger.new
      @odp_config = OdpConfig.new

      unless @enabled
        @logger.log(Logger::INFO, ODP_LOGS[:ODP_NOT_ENABLED])
        return
      end

      unless @segment_manager
        segments_cache ||= LRUCache.new(
          Helpers::Constants::ODP_SEGMENTS_CACHE_CONFIG[:DEFAULT_CAPACITY],
          Helpers::Constants::ODP_SEGMENTS_CACHE_CONFIG[:DEFAULT_TIMEOUT_SECONDS]
        )
        @segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, @logger)
      end

      @event_manager ||= Optimizely::OdpEventManager.new(logger: @logger)

      @segment_manager.odp_config = @odp_config
      @event_manager.start!(@odp_config)
    end

    def fetch_qualified_segments(user_id:, options:)
      # Returns qualified segments for the user from the cache or the ODP server if not in the cache.
      #
      # @param user_id - The user id.
      # @param options - An array of OptimizelySegmentOptions used to ignore and/or reset the cache.
      #
      # @return - Array of qualified segments or nil.
      options ||= []
      unless @enabled
        @logger.log(Logger::ERROR, ODP_LOGS[:ODP_NOT_ENABLED])
        return nil
      end

      if @odp_config.odp_state == ODP_CONFIG_STATE[:UNDETERMINED]
        @logger.log(Logger::ERROR, 'Cannot fetch segments before the datafile has loaded.')
        return nil
      end

      @segment_manager.fetch_qualified_segments(ODP_MANAGER_CONFIG[:KEY_FOR_USER_ID], user_id, options)
    end

    def identify_user(user_id:)
      unless @enabled
        @logger.log(Logger::DEBUG, 'ODP identify event is not dispatched (ODP disabled).')
        return
      end

      case @odp_config.odp_state
      when ODP_CONFIG_STATE[:UNDETERMINED]
        @logger.log(Logger::DEBUG, 'ODP identify event is not dispatched (datafile not ready).')
        return
      when ODP_CONFIG_STATE[:NOT_INTEGRATED]
        @logger.log(Logger::DEBUG, 'ODP identify event is not dispatched (ODP not integrated).')
        return
      end

      @event_manager.send_event(
        type: ODP_MANAGER_CONFIG[:EVENT_TYPE],
        action: 'identified',
        identifiers: {ODP_MANAGER_CONFIG[:KEY_FOR_USER_ID] => user_id},
        data: {}
      )
    end

    def send_event(type:, action:, identifiers:, data:)
      # Send an event to the ODP server.
      #
      # @param type - the event type.
      # @param action - the event action name.
      # @param identifiers - a hash for identifiers.
      # @param data - a hash for associated data. The default event data will be added to this data before sending to the ODP server.
      unless @enabled
        @logger.log(Logger::ERROR, ODP_LOGS[:ODP_NOT_ENABLED])
        return
      end

      unless Helpers::Validator.odp_data_types_valid?(data)
        @logger.log(Logger::ERROR, ODP_LOGS[:ODP_INVALID_DATA])
        return
      end

      @event_manager.send_event(type: type, action: action, identifiers: identifiers, data: data)
    end

    def update_odp_config(api_key, api_host, segments_to_check)
      # Update the odp config, reset the cache and send signal to the event processor to update its config.
      return unless @enabled

      config_changed = @odp_config.update(api_key, api_host, segments_to_check)
      unless config_changed
        @logger.log(Logger::DEBUG, 'Odp config was not changed.')
        return
      end

      @segment_manager.reset
      @event_manager.update_config
    end

    def stop!
      return unless @enabled

      @event_manager.stop!
    end
  end
end
