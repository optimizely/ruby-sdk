#
#    Copyright 2016-2017, Optimizely and contributors
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
require_relative './audience'
require_relative './params'
require_relative './version'
require_relative '../optimizely/helpers/event_tag_utils'
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
    def ==(event)
      @http_verb == event.http_verb && @url == event.url && @params == event.params && @headers == event.headers
    end
  end

  class BaseEventBuilder
    CUSTOM_ATTRIBUTE_FEATURE_TYPE = 'custom'

    attr_reader :config

    def initialize(config)
      @config = config
    end

    private

    def get_common_params(user_id, attributes)
      # Get params which are used in both conversion and impression events.
      # 
      # user_id -    +String+ ID for user
      # attributes - +Hash+ representing user attributes and values which need to be recorded.
      # 
      # Returns +Hash+ Common event params

      visitor_attributes = []

      unless attributes.nil?

        attributes.keys.each do |attribute_key|
        # Omit null attribute value
        attribute_value = attributes[attribute_key]
        next if attribute_value.nil?

        # Skip attributes not in the datafile
        attribute_id = @config.get_attribute_id(attribute_key)
        next unless attribute_id

        feature = {
          entity_id: attribute_id,
          key: attribute_key,
          type: CUSTOM_ATTRIBUTE_FEATURE_TYPE,
          value: attribute_value
        }

        visitor_attributes.push(feature)
        end
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
        anonymize_ip: @config.should_anonymize_ip,
        revision: @config.revision,
        client_name: CLIENT_ENGINE,
        client_version: VERSION
        }

      common_params
    end
  end

  class EventBuilder < BaseEventBuilder
    ENDPOINT = 'https://logx.optimizely.com/v1/events'
    POST_HEADERS = { 'Content-Type' => 'application/json' }
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
      event_params[:visitors][0][:snapshots] = conversion_params;
      
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

      impressionEventParams = {
        decisions: [{
          campaign_id: @config.experiment_key_map[experiment_key]['layerId'],
          experiment_id: experiment_id,
          variation_id: variation_id,
        }],
        events: [{
          entity_id: @config.experiment_key_map[experiment_key]['layerId'],
          timestamp: get_timestamp(),
          key: ACTIVATE_EVENT_KEY,
          uuid: get_uuid()
        }]
      }

      impressionEventParams;
    end

    def get_conversion_params(event_key, event_tags, experiment_variation_map)
      # Creates object of params specific to conversion events
      #
      # event_key -                +String+ Key representing the event which needs to be recorded
      # event_tags -               +Hash+ Values associated with the event.
      # experiment_variation_map - +Hash+ Map of experiment IDs to bucketed variation IDs
      #
      # Returns +Hash+ Impression event params

      conversionEventParams = []

      experiment_variation_map.each do |experiment_id, variation_id|

        single_snapshot = {
          decisions: [{
            campaign_id: @config.experiment_id_map[experiment_id]['layerId'],
            experiment_id: experiment_id,
            variation_id: variation_id,
          }],
          events: [],
        }

        event_object = {
          entity_id: @config.event_key_map[event_key]['id'],
          timestamp: get_timestamp(),
          uuid: get_uuid(),
          key: event_key,
        }

        if event_tags
          revenue_value = Helpers::EventTagUtils.get_revenue_value(event_tags)
          if revenue_value
            event_object[:revenue] = revenue_value
          end

          numeric_value = Helpers::EventTagUtils.get_numeric_value(event_tags)
          if numeric_value
            event_object[:value] = numeric_value
          end

          event_object[:tags] = event_tags
        end

        single_snapshot[:events] = [event_object]

        conversionEventParams.push(single_snapshot)
      end
    
      conversionEventParams
    end

    def get_timestamp
      # Returns +Integer+ Current timestamp

      (Time.now.to_f * 1000).to_i
    end

    def get_uuid
      # Returns +String+ Random UUID

      SecureRandom.uuid
    end
  end
end
