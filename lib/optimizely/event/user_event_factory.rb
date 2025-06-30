# frozen_string_literal: true

#
#    Copyright 2019-2020, Optimizely and contributors
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
require_relative 'entity/conversion_event'
require_relative 'entity/impression_event'
require_relative 'entity/event_context'
require_relative 'event_factory'
module Optimizely
  class UserEventFactory
    # UserEventFactory builds ImpressionEvent and ConversionEvent objects from a given user_event.
    def self.create_impression_event(project_config, experiment, variation_id, metadata, user_id, user_attributes)
      # Create impression Event to be sent to the logging endpoint.
      #
      # project_config - Instance of ProjectConfig
      # experiment -   Instance Experiment for which impression needs to be recorded.
      # variation_id - String ID for variation which would be presented to user.
      # user_id -      String ID for user.
      # attributes -   Hash Representing user attributes and values which need to be recorded.
      #
      # Returns Event encapsulating the impression event.
      event_context = Optimizely::EventContext.new(
        region: project_config.region,
        account_id: project_config.account_id,
        project_id: project_config.project_id,
        anonymize_ip: project_config.anonymize_ip,
        revision: project_config.revision,
        client_name: CLIENT_ENGINE,
        client_version: VERSION
      ).as_json

      visitor_attributes = Optimizely::EventFactory.build_attribute_list(user_attributes, project_config)
      experiment_layer_id = experiment['layerId']
      Optimizely::ImpressionEvent.new(
        event_context: event_context,
        user_id: user_id,
        experiment_layer_id: experiment_layer_id,
        experiment_id: experiment['id'],
        variation_id: variation_id,
        metadata: metadata,
        visitor_attributes: visitor_attributes,
        bot_filtering: project_config.bot_filtering
      )
    end

    def self.create_conversion_event(project_config, event, user_id, user_attributes, event_tags)
      # Create conversion Event to be sent to the logging endpoint.
      #
      # project_config - Instance of ProjectConfig
      # event - Event which needs to be recorded.
      # user_id - String ID for user.
      # attributes - Hash Representing user attributes and values which need to be recorded.
      # event_tags - Hash representing metadata associated with the event.
      #
      # Returns Event encapsulating the conversion event.

      event_context = Optimizely::EventContext.new(
        region: project_config.region,
        account_id: project_config.account_id,
        project_id: project_config.project_id,
        anonymize_ip: project_config.anonymize_ip,
        revision: project_config.revision,
        client_name: CLIENT_ENGINE,
        client_version: VERSION
      ).as_json

      Optimizely::ConversionEvent.new(
        event_context: event_context,
        event: event,
        user_id: user_id,
        visitor_attributes: Optimizely::EventFactory.build_attribute_list(user_attributes, project_config),
        tags: event_tags,
        bot_filtering: project_config.bot_filtering
      )
    end
  end
end
