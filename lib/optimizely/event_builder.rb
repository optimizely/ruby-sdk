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
    attr_reader :bucketer
    attr_accessor :params

    def initialize(config, bucketer)
      @config = config
      @bucketer = bucketer
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

    def create_conversion_event(event_key, user_id, attributes, event_tags, experiment_keys)
      # Create conversion Event to be sent to the logging endpoint.
      #
      # event_key - Event key representing the event which needs to be recorded.
      # user_id - ID for user.
      # attributes - Hash representing user attributes and values which need to be recorded.
      # event_tags - Hash representing metadata associated with the event.
      # experiment_keys - Array of valid experiment keys for the event
      #
      # Returns event hash encapsulating the conversion event.

      @params = {}
      add_common_params(user_id, attributes)
      add_conversion_event(event_key)
      add_event_tags(event_tags)
      add_layer_states(user_id, experiment_keys)
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

    def add_layer_states(user_id, experiment_keys)
      @params['layerStates'] = []

      experiment_keys.each do |experiment_key|
        variation_id = @bucketer.bucket(experiment_key, user_id)
        experiment_id = @config.experiment_key_map[experiment_key]['id']
        layer_state = {
          'layerId' => @config.experiment_key_map[experiment_key]['layerId'],
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

  class EventBuilderV1 < BaseEventBuilder
    # Class which encapsulates methods to build events for tracking impressions and conversions.

    # Attribute mapping format
    ATTRIBUTE_PARAM_FORMAT = '%{segment_prefix}%{segment_id}'

    # Experiment mapping format
    EXPERIMENT_PARAM_FORMAT = '%{experiment_prefix}%{experiment_id}'

    # Event endpoint path
    OFFLINE_API_PATH = 'https://%{project_id}.log.optimizely.com/event'

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
      add_impression_goal(experiment_key)
      add_experiment(experiment_key, variation_id)
      Event.new(:get, sprintf(OFFLINE_API_PATH, project_id: @params[Params::PROJECT_ID]), @params, {})
    end

    def create_conversion_event(event_key, user_id, attributes, event_tags, experiment_keys)
      # Create conversion Event to be sent to the logging endpoint.
      #
      # event_key - Goal key representing the event which needs to be recorded.
      # user_id - ID for user.
      # attributes - Hash representing user attributes and values which need to be recorded.
      # event_tags - Hash representing metadata associated with the event.
      # experiment_keys - Array of valid experiment keys for the goal
      #
      # Returns event hash encapsulating the conversion event.

      @params = {}

      event_value = Helpers::EventTagUtils.get_revenue_value(event_tags)

      add_common_params(user_id, attributes)
      add_conversion_goal(event_key, event_value)
      add_experiment_variation_params(user_id, experiment_keys)
      Event.new(:get, sprintf(OFFLINE_API_PATH, project_id: @params[Params::PROJECT_ID]), @params, {})
    end

    private

    def add_project_id
      # Add project ID to the event.

      @params[Params::PROJECT_ID] = @config.project_id
    end

    def add_account_id
      # Add account ID to the event.

      @params[Params::ACCOUNT_ID] = @config.account_id
    end

    def add_user_id(user_id)
      # Add user ID to the event.

      @params[Params::END_USER_ID] = user_id
    end

    def add_attributes(attributes)
      # Add attribute(s) information to the event.
      #
      # attributes - Hash representing user attributes and values which need to be recorded.

      return if attributes.nil?

      attributes.keys.each do |attribute_key|
        attribute_value = attributes[attribute_key]
        next unless attribute_value

        # Skip attributes not in the datafile
        segment_id = @config.get_segment_id(attribute_key)
        next unless segment_id
        segment_param = sprintf(ATTRIBUTE_PARAM_FORMAT,
                                segment_prefix: Params::SEGMENT_PREFIX, segment_id: segment_id)
        params[segment_param] = attribute_value
      end
    end

    def add_source
      # Add source information to the event.

      @params[Params::SOURCE] = sprintf('ruby-sdk-%{version}', version: VERSION)
    end

    def add_time
      # Add time information to the event.

      @params[Params::TIME] = Time.now.strftime('%s').to_i
    end

    def add_impression_goal(experiment_key)
      # Add impression goal information to the event.
      #
      # experiment_key - Experiment which is being activated.

      # For tracking impressions, goal ID is set equal to experiment ID of experiment being activated.
      @params[Params::GOAL_ID] = @config.get_experiment_id(experiment_key)
      @params[Params::GOAL_NAME] = 'visitor-event'
    end

    def add_experiment(experiment_key, variation_id)
      # Add experiment to variation mapping to the impression event.
      #
      # experiment_key - Experiment which is being activated.
      # variation_id - ID for variation which would be presented to user.

      experiment_id = @config.get_experiment_id(experiment_key)
      experiment_param = sprintf(EXPERIMENT_PARAM_FORMAT,
                                 experiment_prefix: Params::EXPERIMENT_PREFIX, experiment_id: experiment_id)
      @params[experiment_param] = variation_id
    end

    def add_experiment_variation_params(user_id, experiment_keys)
      # Maps experiment and corresponding variation as parameters to be used in the event tracking call.
      #
      # user_id - ID for user.
      # experiment_keys - Array of valid experiment keys for the goal

      experiment_keys.each do |experiment_key|
        variation_id = @bucketer.bucket(experiment_key, user_id)
        experiment_id = @config.experiment_key_map[experiment_key]['id']
        experiment_param = sprintf(EXPERIMENT_PARAM_FORMAT,
                                   experiment_prefix: Params::EXPERIMENT_PREFIX, experiment_id: experiment_id)
        @params[experiment_param] = variation_id
      end
    end

    def add_conversion_goal(event_key, event_value)
      # Add conversion goal information to the event.
      #
      # event_key - Goal key representing the event which needs to be recorded.
      # event_value - Value associated with the event. Can be used to represent revenue in cents.

      goal_id = @config.event_key_map[event_key]['id']
      event_ids = goal_id

      if event_value
        event_ids = sprintf('%{goal_id},%{revenue_id}', goal_id: goal_id, revenue_id: @config.get_revenue_goal_id)
        @params[Params::EVENT_VALUE] = event_value
      end

      @params[Params::GOAL_ID] = event_ids
      @params[Params::GOAL_NAME] = event_key
    end
  end
end
