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
    attr_reader :config
    attr_accessor :params

    def initialize(config)
      @config = config
      @params = {}
    end

    private

    def add_common_params(user_id, attributes)
      # Add params which are used in both conversion and impression events.
      #
      # user_id - ID for user.
      # attributes - Hash representing user attributes and values which need to be recorded.

      add_project_id
      add_account_id
      add_user_id(user_id)
      add_attributes(attributes)
      add_source
      add_time
    end
  end

  class EventBuilderV2 < BaseEventBuilder
    CONVERSION_EVENT_ENDPOINT = 'https://logx.optimizely.com/log/event'
    IMPRESSION_EVENT_ENDPOINT = 'https://logx.optimizely.com/log/decision'
    POST_HEADERS = { 'Content-Type' => 'application/json' }

    def create_impression_event(experiment_key, variation_id, user_id, attributes)
      # Create conversion Event to be sent to the logging endpoint.
      #
      # experiment_key - Experiment for which impression needs to be recorded.
      # variation_id - ID for variation which would be presented to user.
      # user_id - ID for user.
      # attributes - Hash representing user attributes and values which need to be recorded.
      #
      # Returns event hash encapsulating the impression event.

      @params = {}
      add_common_params(user_id, attributes)
      add_decision(experiment_key, variation_id)
      add_attributes(attributes)
      Event.new(:post, IMPRESSION_EVENT_ENDPOINT, @params, POST_HEADERS)
    end

    def create_conversion_event(event_key, user_id, attributes, event_tags, experiment_variation_map)
      # Create conversion Event to be sent to the logging endpoint.
      #
      # event_key - Event key representing the event which needs to be recorded.
      # user_id - ID for user.
      # attributes - Hash representing user attributes and values which need to be recorded.
      # event_tags - Hash representing metadata associated with the event.
      # experiment_variation_map - Map of experiment ID to the ID of the variation that the user is bucketed into.
      #
      # Returns event hash encapsulating the conversion event.

      @params = {}
      add_common_params(user_id, attributes)
      add_conversion_event(event_key)
      add_event_tags(event_tags)
      add_layer_states(experiment_variation_map)
      Event.new(:post, CONVERSION_EVENT_ENDPOINT, @params, POST_HEADERS)
    end

    private

    def add_common_params(user_id, attributes)
      super
      @params['isGlobalHoldback'] = false
    end

    def add_project_id
      @params['projectId'] = @config.project_id
    end

    def add_account_id
      @params['accountId'] = @config.account_id
    end

    def add_user_id(user_id)
      @params['visitorId'] = user_id
    end

    def add_attributes(attributes)
      @params['userFeatures'] = []

      return if attributes.nil?

      attributes.keys.each do |attribute_key|
        # Omit falsy attribute values
        attribute_value = attributes[attribute_key]
        next unless attribute_value

        # Skip attributes not in the datafile
        attribute_id = @config.get_attribute_id(attribute_key)
        next unless attribute_id

        feature = {
          'id' => attribute_id,
          'name' => attribute_key,
          'type' => 'custom',
          'value' => attribute_value,
          'shouldIndex' => true,
        }
        @params['userFeatures'].push(feature)
      end
    end

    def add_decision(experiment_key, variation_id)
      experiment_id = @config.get_experiment_id(experiment_key)
      @params['layerId'] = @config.experiment_key_map[experiment_key]['layerId']
      @params['decision'] = {
        'variationId' => variation_id,
        'experimentId' => experiment_id,
        'isLayerHoldback' => false,
      }
    end

    def add_event_tags(event_tags)
      @params['eventFeatures'] ||= []
      @params['eventMetrics'] ||= []

      return if event_tags.nil?

      event_tags.each_pair do |event_tag_key, event_tag_value|
        next if event_tag_value.nil?

        event_feature = {
          'name' => event_tag_key,
          'type' => 'custom',
          'value' => event_tag_value,
          'shouldIndex' => false,
        }
        @params['eventFeatures'].push(event_feature)

      end

      event_value = Helpers::EventTagUtils.get_revenue_value(event_tags)

      if event_value
        event_metric = {
          'name' => 'revenue',
          'value' => event_value
        }
        @params['eventMetrics'].push(event_metric)
      end

    end

    def add_conversion_event(event_key)
      # Add conversion event information to the event.
      #
      # event_key - Event key representing the event which needs to be recorded.

      event_id = @config.event_key_map[event_key]['id']
      event_name = @config.event_key_map[event_key]['key']

      @params['eventEntityId'] = event_id
      @params['eventName'] = event_name
    end

    def add_layer_states(experiments_map)
      # Add layer states information to the event.
      #
      # experiments_map - Hash with experiment ID as a key and variation ID as a value.

      @params['layerStates'] = []

      experiments_map.each do |experiment_id, variation_id|
        layer_state = {
          'layerId' => @config.experiment_id_map[experiment_id]['layerId'],
          'decision' => {
            'variationId' => variation_id,
            'experimentId' => experiment_id,
            'isLayerHoldback' => false,
          },
          'actionTriggered' => true,
        }
        @params['layerStates'].push(layer_state)
      end
    end

    def add_source
      @params['clientEngine'] = 'ruby-sdk'
      @params['clientVersion'] = VERSION
    end

    def add_time
      @params['timestamp'] = (Time.now.to_f * 1000).to_i
    end
  end
end
