# frozen_string_literal: true

#
#    Copyright 2016-2019, 2022-2023, Optimizely and contributors
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

    attr_reader :http_verb, :params, :url, :headers

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

    def initialize(logger)
      @logger = logger
    end

    private

    def get_common_params(project_config, user_id, attributes)
      # Get params which are used in both conversion and impression events.
      #
      # project_config - +Object+ Instance of ProjectConfig
      # user_id -    +String+ ID for user
      # attributes - +Hash+ representing user attributes and values which need to be recorded.
      #
      # Returns +Hash+ Common event params

      visitor_attributes = []

      attributes&.each_key do |attribute_key|
        # Omit attribute values that are not supported by the log endpoint.
        attribute_value = attributes[attribute_key]
        next unless Helpers::Validator.attribute_valid?(attribute_key, attribute_value)

        attribute_id = project_config.get_attribute_id attribute_key
        next unless attribute_id

        visitor_attributes.push(
          entity_id: attribute_id,
          key: attribute_key,
          type: CUSTOM_ATTRIBUTE_FEATURE_TYPE,
          value: attribute_value
        )
      end
      # Append Bot Filtering Attribute
      if [true, false].include?(project_config.bot_filtering)
        visitor_attributes.push(
          entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          type: CUSTOM_ATTRIBUTE_FEATURE_TYPE,
          value: project_config.bot_filtering
        )
      end

      {
        account_id: project_config.account_id,
        project_id: project_config.project_id,
        visitors: [
          {
            attributes: visitor_attributes,
            snapshots: [],
            visitor_id: user_id
          }
        ],
        anonymize_ip: project_config.anonymize_ip,
        revision: project_config.revision,
        client_name: CLIENT_ENGINE,
        enrich_decisions: true,
        client_version: VERSION,
        region: project_config.region || 'US'
      }
    end
  end

  class EventBuilder < BaseEventBuilder
    ENDPOINTS = {
      US: 'https://logx.optimizely.com/v1/events',
      EU: 'https://eu.logx.optimizely.com/v1/events'
    }.freeze
    POST_HEADERS = {'Content-Type' => 'application/json'}.freeze
    ACTIVATE_EVENT_KEY = 'campaign_activated'

    def create_impression_event(project_config, experiment, variation_id, user_id, attributes)
      # Create impression Event to be sent to the logging endpoint.
      #
      # project_config - +Object+ Instance of ProjectConfig
      # experiment -   +Object+ Experiment for which impression needs to be recorded.
      # variation_id - +String+ ID for variation which would be presented to user.
      # user_id -      +String+ ID for user.
      # attributes -   +Hash+ representing user attributes and values which need to be recorded.
      #
      # Returns +Event+ encapsulating the impression event.

      region = project_config.region || 'US'
      event_params = get_common_params(project_config, user_id, attributes)
      impression_params = get_impression_params(project_config, experiment, variation_id)
      event_params[:visitors][0][:snapshots].push(impression_params)

      endpoint = ENDPOINTS[region.to_s.upcase.to_sym]

      Event.new(:post, endpoint, event_params, POST_HEADERS)
    end

    def create_conversion_event(project_config, event, user_id, attributes, event_tags)
      # Create conversion Event to be sent to the logging endpoint.
      #
      # project_config -           +Object+ Instance of ProjectConfig
      # event -                    +Object+ Event which needs to be recorded.
      # user_id -                  +String+ ID for user.
      # attributes -               +Hash+ representing user attributes and values which need to be recorded.
      # event_tags -               +Hash+ representing metadata associated with the event.
      #
      # Returns +Event+ encapsulating the conversion event.

      region = project_config.region || 'US'
      event_params = get_common_params(project_config, user_id, attributes)
      conversion_params = get_conversion_params(event, event_tags)
      event_params[:visitors][0][:snapshots] = [conversion_params]

      endpoint = ENDPOINTS[region.to_s.upcase.to_sym]

      Event.new(:post, endpoint, event_params, POST_HEADERS)
    end

    private

    def get_impression_params(project_config, experiment, variation_id)
      # Creates object of params specific to impression events
      #
      # project_config - +Object+ Instance of ProjectConfig
      # experiment -   +Hash+ experiment for which impression needs to be recorded
      # variation_id - +string+ ID for variation which would be presented to user
      #
      # Returns +Hash+ Impression event params

      experiment_key = experiment['key']
      experiment_id = experiment['id']

      campaign_id = experiment&.dig('campaignId') || experiment&.dig('layerId')
      if decision_source == Optimizely::DecisionService::DECISION_SOURCES['HOLDOUT']
        campaign_id = ''
        entity_id = ''
      else
        entity_id = campaign_id
      end

      {
        decisions: [{
          campaign_id: campaign_id
          experiment_id: experiment_id,
          variation_id: variation_id
        }],
        events: [{
          entity_id: entity_id,
          timestamp: create_timestamp,
          key: ACTIVATE_EVENT_KEY,
          uuid: create_uuid
        }]
      }
    end

    def get_conversion_params(event, event_tags)
      # Creates object of params specific to conversion events
      #
      # event -                    +Object+ Event which needs to be recorded.
      # event_tags -               +Hash+ Values associated with the event.
      #
      # Returns +Hash+ Conversion event params

      single_snapshot = {}
      event_object = {
        entity_id: event['id'],
        timestamp: create_timestamp,
        uuid: create_uuid,
        key: event['key']
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
