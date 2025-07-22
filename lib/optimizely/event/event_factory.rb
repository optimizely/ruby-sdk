# frozen_string_literal: true

#
#    Copyright 2019-2020, 2022-2023, Optimizely and contributors
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
require_relative 'entity/event_batch'
require_relative 'entity/conversion_event'
require_relative 'entity/decision'
require_relative 'entity/impression_event'
require_relative 'entity/snapshot'
require_relative 'entity/snapshot_event'
require_relative 'entity/visitor'
require 'optimizely/helpers/validator'
module Optimizely
  class EventFactory
    # EventFactory builds LogEvent objects from a given user_event.
    class << self
      CUSTOM_ATTRIBUTE_FEATURE_TYPE = 'custom'
      ENDPOINTS = {
        US: 'https://logx.optimizely.com/v1/events',
        EU: 'https://eu.logx.optimizely.com/v1/events'
      }.freeze
      POST_HEADERS = {'Content-Type' => 'application/json'}.freeze
      ACTIVATE_EVENT_KEY = 'campaign_activated'

      def create_log_event(user_events, logger)
        @logger = logger
        builder = Optimizely::EventBatch::Builder.new

        user_events = [user_events] unless user_events.is_a? Array

        visitors = []
        user_context = nil
        user_events.each do |user_event|
          case user_event
          when Optimizely::ImpressionEvent
            visitor = create_impression_event_visitor(user_event)
            visitors.push(visitor)
          when Optimizely::ConversionEvent
            visitor = create_conversion_event_visitor(user_event)
            visitors.push(visitor)
          else
            @logger.log(Logger::WARN, 'invalid UserEvent added in a list.')
            next
          end
          user_context = user_event.event_context
        end

        return nil if visitors.empty?

        builder.with_account_id(user_context[:account_id])
        builder.with_project_id(user_context[:project_id])
        builder.with_client_version(user_context[:client_version])
        builder.with_revision(user_context[:revision])
        builder.with_client_name(user_context[:client_name])
        builder.with_anonymize_ip(user_context[:anonymize_ip])
        builder.with_enrich_decisions(true)

        builder.with_visitors(visitors)
        event_batch = builder.build

        endpoint = ENDPOINTS[user_context[:region].to_s.upcase.to_sym] || ENDPOINTS[:US]

        Event.new(:post, endpoint, event_batch.as_json, POST_HEADERS)
      end

      def build_attribute_list(user_attributes, project_config)
        visitor_attributes = []
        user_attributes&.each_key do |attribute_key|
          # Omit attribute values that are not supported by the log endpoint.
          attribute_value = user_attributes[attribute_key]
          next unless Helpers::Validator.attribute_valid?(attribute_key, attribute_value)

          attribute_id = project_config.get_attribute_id attribute_key
          next if attribute_id.nil?

          visitor_attributes.push(
            entity_id: attribute_id,
            key: attribute_key,
            type: CUSTOM_ATTRIBUTE_FEATURE_TYPE,
            value: attribute_value
          )
        end

        return visitor_attributes unless Helpers::Validator.boolean? project_config.bot_filtering

        # Append Bot Filtering Attribute
        visitor_attributes.push(
          entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          type: CUSTOM_ATTRIBUTE_FEATURE_TYPE,
          value: project_config.bot_filtering
        )
      end

      private

      def create_impression_event_visitor(impression_event)
        decision = Decision.new(
          campaign_id: impression_event.experiment_layer_id,
          experiment_id: impression_event.experiment_id,
          variation_id: impression_event.variation_id,
          metadata: impression_event.metadata
        )

        snapshot_event = Optimizely::SnapshotEvent.new(
          entity_id: impression_event.experiment_layer_id,
          timestamp: impression_event.timestamp,
          uuid: impression_event.uuid,
          key: ACTIVATE_EVENT_KEY
        )

        snapshot = Optimizely::Snapshot.new(
          events: [snapshot_event.as_json],
          decisions: [decision.as_json]
        )

        visitor = Optimizely::Visitor.new(
          snapshots: [snapshot.as_json],
          visitor_id: impression_event.user_id,
          attributes: impression_event.visitor_attributes
        )
        visitor.as_json
      end

      def create_conversion_event_visitor(conversion_event)
        revenue_value = Helpers::EventTagUtils.get_revenue_value(conversion_event.tags, @logger)
        numeric_value = Helpers::EventTagUtils.get_numeric_value(conversion_event.tags, @logger)
        snapshot_event = Optimizely::SnapshotEvent.new(
          entity_id: conversion_event.event['id'],
          timestamp: conversion_event.timestamp,
          uuid: conversion_event.uuid,
          key: conversion_event.event['key'],
          revenue: revenue_value,
          value: numeric_value,
          tags: conversion_event.tags
        )

        snapshot = Optimizely::Snapshot.new(events: [snapshot_event.as_json])

        visitor = Optimizely::Visitor.new(
          snapshots: [snapshot.as_json],
          visitor_id: conversion_event.user_id,
          attributes: conversion_event.visitor_attributes
        )
        visitor.as_json
      end
    end
  end
end
