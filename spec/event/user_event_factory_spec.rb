# frozen_string_literal: true

#
#    Copyright 2016-2020, Optimizely and contributors
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
require 'spec_helper'
require 'optimizely/event/user_event_factory'
require 'optimizely/error_handler'
require 'optimizely/logger'
describe Optimizely::UserEventFactory do
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:event) { project_config.get_event_from_key('test_event') }

  describe '.create_impression_event' do
    it 'should return Impression Event when called without attributes' do
      experiment = project_config.get_experiment_from_key('test_experiment')
      impression_event = Optimizely::UserEventFactory.create_impression_event(
        project_config,
        experiment,
        '111128',
        {
          flag_key: '',
          rule_key: 'test_experiment',
          rule_type: 'experiment',
          variation_key: 'control'
        },
        'test_user',
        nil
      )
      expect(impression_event.event_context[:account_id]).to eq(project_config.account_id)
      expect(impression_event.event_context[:project_id]).to eq(project_config.project_id)
      expect(impression_event.event_context[:revision]).to eq(project_config.revision)
      expect(impression_event.event_context[:anonymize_ip]).to eq(project_config.anonymize_ip)
      expect(impression_event.event_context[:region]).to eq(project_config.region)
      expect(impression_event.bot_filtering).to eq(project_config.bot_filtering)
      expect(impression_event.experiment_id).to eq(experiment['id'])
      expect(impression_event.variation_id).to eq('111128')
      expect(impression_event.user_id).to eq('test_user')
    end

    it 'should return Impression Event when called with attributes' do
      user_attributes = {
        'browser_type' => 'firefox',
        'device' => 'iPhone'
      }

      experiment = project_config.get_experiment_from_key('test_experiment')
      impression_event = Optimizely::UserEventFactory.create_impression_event(
        project_config,
        experiment,
        '111128',
        {
          flag_key: '',
          rule_key: 'test_experiment',
          rule_type: 'experiment',
          variation_key: 'control'
        },
        'test_user',
        user_attributes
      )

      expected_visitor_attributes = Optimizely::EventFactory.build_attribute_list(user_attributes, project_config)

      expect(impression_event.event_context[:account_id]).to eq(project_config.account_id)
      expect(impression_event.event_context[:project_id]).to eq(project_config.project_id)
      expect(impression_event.event_context[:revision]).to eq(project_config.revision)
      expect(impression_event.event_context[:anonymize_ip]).to eq(project_config.anonymize_ip)
      expect(impression_event.event_context[:region]).to eq(project_config.region)
      expect(impression_event.bot_filtering).to eq(project_config.bot_filtering)
      expect(impression_event.experiment_id).to eq(experiment['id'])
      expect(impression_event.variation_id).to eq('111128')
      expect(impression_event.user_id).to eq('test_user')
      expect(impression_event.visitor_attributes).to eq(expected_visitor_attributes)
    end
  end

  describe '.create_conversion_event' do
    it 'should return Conversion Event when called without event tags' do
      user_attributes = {
        'browser_type' => 'firefox',
        'device' => 'iPhone'
      }

      conversion_event = Optimizely::UserEventFactory.create_conversion_event(
        project_config,
        event,
        'test_user',
        user_attributes,
        nil
      )

      expected_visitor_attributes = Optimizely::EventFactory.build_attribute_list(user_attributes, project_config)

      expect(conversion_event.event_context[:account_id]).to eq(project_config.account_id)
      expect(conversion_event.event_context[:project_id]).to eq(project_config.project_id)
      expect(conversion_event.event_context[:revision]).to eq(project_config.revision)
      expect(conversion_event.event_context[:anonymize_ip]).to eq(project_config.anonymize_ip)
      expect(impression_event.event_context[:region]).to eq(project_config.region)
      expect(conversion_event.event['key']).to eq(event['key'])
      expect(conversion_event.bot_filtering).to eq(project_config.bot_filtering)
      expect(conversion_event.user_id).to eq('test_user')
      expect(conversion_event.tags).to eq(nil)
      expect(conversion_event.visitor_attributes).to eq(expected_visitor_attributes)
    end

    it 'should return Conversion Event when called with event tags' do
      user_attributes = {
        'browser_type' => 'firefox',
        'device' => 'iPhone'
      }

      event_tags = {
        'revenue' => 4200,
        'value' => 13.37,
        'non-revenue' => 'test'
      }

      conversion_event = Optimizely::UserEventFactory.create_conversion_event(
        project_config,
        event,
        'test_user',
        user_attributes,
        event_tags
      )

      expected_visitor_attributes = Optimizely::EventFactory.build_attribute_list(user_attributes, project_config)

      expect(conversion_event.event_context[:account_id]).to eq(project_config.account_id)
      expect(conversion_event.event_context[:project_id]).to eq(project_config.project_id)
      expect(conversion_event.event_context[:revision]).to eq(project_config.revision)
      expect(conversion_event.event_context[:anonymize_ip]).to eq(project_config.anonymize_ip)
      expect(impression_event.event_context[:region]).to eq(project_config.region)
      expect(conversion_event.event['key']).to eq(event['key'])
      expect(conversion_event.bot_filtering).to eq(project_config.bot_filtering)
      expect(conversion_event.user_id).to eq('test_user')
      expect(conversion_event.tags).to eq(event_tags)
      expect(conversion_event.visitor_attributes).to eq(expected_visitor_attributes)
    end
  end
end
