# frozen_string_literal: true

#
#    Copyright 2016-2018, Optimizely and contributors
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
require_relative 'audience'
require_relative 'helpers/constants'
require_relative 'helpers/event_tag_utils'
require_relative 'params'
require_relative 'version'

require 'securerandom'

module Optimizely
  class Event
    # Representation of an event which can be sent to the Optimizely logging endpoint.

    attr_reader :http_verb
    attr_reader :params
    attr_reader :url
    attr_reader :headers

    def initialize(http_verb, url, params, headers)
      @http_verb = http_verb
      @url = url
      @params = params
      @headers = headers
    end

    # Override equality operator to make two events with the same contents equal for testing purposes
    def ==(other)
      @http_verb == other.http_verb && @url == other.url && @params == other.params && @headers == other.headers
    end
  end

  class BaseEventBuilder
    CUSTOM_ATTRIBUTE_FEATURE_TYPE = 'custom'

    attr_reader :config
    attr_reader :logger

    def initialize(config, logger)
      @config = config
      @logger = logger
    end

    private

    def bot_filtering
      # Get bot filtering bool
      #
      # Returns 'botFiltering' value in the datafile.
      @config.bot_filtering
    end

    def get_common_params(user_id, attributes)
      # Get params which are used in both conversion and impression events.
      #
      # user_id -    +String+ ID for user
      # attributes - +Hash+ representing user attributes and values which need to be recorded.
      #
      # Returns +Hash+ Common event params

      visitor_attributes = []

      attributes&.keys&.each do |attribute_key|
        # Omit invalid attribute values.
        attribute_value = attributes[attribute_key]
        if Helpers::Validator.attribute_value_type_valid?(attribute_value)
          attribute_id = @config.get_attribute_id attribute_key
          if attribute_id
            visitor_attributes.push(
              entity_id: attribute_id,
              key: attribute_key,
              type: CUSTOM_ATTRIBUTE_FEATURE_TYPE,
              value: attribute_value
            )
          end
        end
      end
      # Append Bot Filtering Attribute
      if bot_filtering == true || bot_filtering == false
        visitor_attributes.push(
          entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          type: CUSTOM_ATTRIBUTE_FEATURE_TYPE,
          value: bot_filtering
        )
      end

      common_params = {
        account_id: @config.account_id,
        project_id: @config.project_id,
        visitors: [
          {
            attributes: visitor_attributes,
            snapshots: [],
            visitor_id: user_id
          }
        ],
        anonymize_ip: @config.anonymize_ip,
        revision: @config.revision,
        client_name: CLIENT_ENGINE,
        client_version: VERSION
      }

      common_params
    end
  end

  class EventBuilder < BaseEventBuilder
    ENDPOINT = 'https://logx.optimizely.com/v1/events'
    POST_HEADERS = {'Content-Type' => 'application/json'}.freeze
    ACTIVATE_EVENT_KEY = 'campaign_activated'

    def create_impression_event(experiment, variation_id, user_id, attributes)
      # Create impression Event to be sent to the logging endpoint.
      #
      # experiment -   +Object+ Experiment for which impression needs to be recorded.
      # variation_id - +String+ ID for variation which would be presented to user.
      # user_id -      +String+ ID for user.
      # attributes -   +Hash+ representing user attributes and values which need to be recorded.
      #
      # Returns +Event+ encapsulating the impression event.

      event_params = get_common_params(user_id, attributes)
      impression_params = get_impression_params(experiment, variation_id)
      event_params[:visitors][0][:snapshots].push(impression_params)

      Event.new(:post, ENDPOINT, event_params, POST_HEADERS)
    end

    def create_conversion_event(event_key, user_id, attributes, event_tags, experiment_variation_map)
      # Create conversion Event to be sent to the logging endpoint.
      #
      # event_key -                +String+ Event key representing the event which needs to be recorded.
      # user_id -                  +String+ ID for user.
      # attributes -               +Hash+ representing user attributes and values which need to be recorded.
      # event_tags -               +Hash+ representing metadata associated with the event.
      # experiment_variation_map - +Map+ of experiment ID to the ID of the variation that the user is bucketed into.
      #
      # Returns +Event+ encapsulating the conversion event.

      event_params = get_common_params(user_id, attributes)
      conversion_params = get_conversion_params(event_key, event_tags, experiment_variation_map)
      event_params[:visitors][0][:snapshots] = [conversion_params]

      Event.new(:post, ENDPOINT, event_params, POST_HEADERS)
    end

    private

    def get_impression_params(experiment, variation_id)
      # Creates object of params specific to impression events
      #
      # experiment -   +Hash+ experiment for which impression needs to be recorded
      # variation_id - +string+ ID for variation which would be presented to user
      #
      # Returns +Hash+ Impression event params

      experiment_key = experiment['key']
      experiment_id = experiment['id']

      impression_event_params = {
        decisions: [{
          campaign_id: @config.experiment_key_map[experiment_key]['layerId'],
          experiment_id: experiment_id,
          variation_id: variation_id
        }],
        events: [{
          entity_id: @config.experiment_key_map[experiment_key]['layerId'],
          timestamp: create_timestamp,
          key: ACTIVATE_EVENT_KEY,
          uuid: create_uuid
        }]
      }

      impression_event_params
    end

    def get_conversion_params(event_key, event_tags, experiment_variation_map)
      # Creates object of params specific to conversion events
      #
      # event_key -                +String+ Key representing the event which needs to be recorded
      # event_tags -               +Hash+ Values associated with the event.
      # experiment_variation_map - +Hash+ Map of experiment IDs to bucketed variation IDs
      #
      # Returns +Hash+ Conversion event params

      single_snapshot = {}
      single_snapshot[:decisions] = []
      experiment_variation_map.each do |experiment_id, variation_id|
        next unless variation_id
        single_snapshot[:decisions].push(
          campaign_id: @config.experiment_id_map[experiment_id]['layerId'],
          experiment_id: experiment_id,
          variation_id: variation_id
        )
      end

      event_object = {
        entity_id: @config.event_key_map[event_key]['id'],
        timestamp: create_timestamp,
        uuid: create_uuid,
        key: event_key
      }

      if event_tags
        revenue_value = Helpers::EventTagUtils.get_revenue_value(event_tags, @logger)
        event_object[:revenue] = revenue_value if revenue_value

        numeric_value = Helpers::EventTagUtils.get_numeric_value(event_tags, @logger)
        event_object[:value] = numeric_value if numeric_value

        event_object[:tags] = event_tags unless event_tags.empty?
      end

      single_snapshot[:events] = [event_object]
      single_snapshot
    end

    def create_timestamp
      # Returns +Integer+ Current timestamp

      (Time.now.to_f * 1000).to_i
    end

    def create_uuid
      # Returns +String+ Random UUID

      SecureRandom.uuid
    end
  end
end
