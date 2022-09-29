# frozen_string_literal: true

#
#    Copyright 2020, 2022, Optimizely and contributors
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
require 'optimizely'
require 'optimizely/optimizely_user_context'

describe 'Optimizely' do
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:config_body_invalid_JSON) { OptimizelySpec::INVALID_CONFIG_BODY_JSON }
  let(:forced_decision_JSON) { OptimizelySpec::DECIDE_FORCED_DECISION_JSON }
  let(:integration_JSON) { OptimizelySpec::CONFIG_DICT_WITH_INTEGRATIONS_JSON }
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_instance) { Optimizely::Project.new(config_body_JSON, nil, spy_logger, error_handler) }
  let(:forced_decision_project_instance) { Optimizely::Project.new(forced_decision_JSON, nil, spy_logger, error_handler) }
  let(:integration_project_instance) { Optimizely::Project.new(integration_JSON, nil, spy_logger, error_handler) }
  let(:impression_log_url) { 'https://logx.optimizely.com/v1/events' }
  let(:good_response_data) do
    {
      data: {
        customer: {
          audiences: {
            edges: [
              {
                node: {
                  name: 'a',
                  state: 'qualified',
                  description: 'qualifed sample 1'
                }
              },
              {
                node: {
                  name: 'b',
                  state: 'qualified',
                  description: 'qualifed sample 2'
                }
              },
              {
                node: {
                  name: 'c',
                  state: 'not_qualified',
                  description: 'not-qualified sample'
                }
              }
            ]
          }
        }
      }
    }
  end
  after(:example) do
    project_instance.close
    forced_decision_project_instance.close
    integration_project_instance.close
  end

  describe '#initialize' do
    it 'should set passed value as expected' do
      user_id = 'test_user'
      attributes = {' browser' => 'firefox'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, attributes)

      expect(user_context_obj.instance_variable_get(:@optimizely_client)).to eq(project_instance)
      expect(user_context_obj.instance_variable_get(:@user_id)).to eq(user_id)
      expect(user_context_obj.instance_variable_get(:@user_attributes)).to eq(attributes)
    end

    it 'should set user attributes to empty hash when passed nil' do
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, 'test_user', nil)
      expect(user_context_obj.instance_variable_get(:@user_attributes)).to eq({})
    end
  end

  describe '#set_attribute' do
    it 'should add attribute key and value is attributes hash' do
      user_id = 'test_user'
      attributes = {' browser' => 'firefox'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, attributes)
      user_context_obj.set_attribute('id', 49)

      expected_attributes = attributes
      expected_attributes['id'] = 49
      expect(user_context_obj.instance_variable_get(:@user_attributes)).to eq(expected_attributes)
    end

    it 'should override attribute value if key already exists in hash' do
      user_id = 'test_user'
      attributes = {' browser' => 'firefox', 'color' => ' red'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, attributes)
      user_context_obj.set_attribute('browser', 'chrome')

      expected_attributes = attributes
      expected_attributes['browser'] = 'chrome'

      expect(user_context_obj.instance_variable_get(:@user_attributes)).to eq(expected_attributes)
    end

    it 'should not alter original attributes object when attrubute is modified in the user context' do
      user_id = 'test_user'
      original_attributes = {'browser' => 'firefox'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, original_attributes)
      user_context_obj.set_attribute('id', 49)
      expect(user_context_obj.instance_variable_get(:@user_attributes)).to eq(
        'browser' => 'firefox',
        'id' => 49
      )
      expect(original_attributes).to eq('browser' => 'firefox')
    end
  end

  describe '#forced_decisions' do
    it 'should return status for datafile in forced decision calls' do
      user_id = 'test_user'
      original_attributes = {}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, original_attributes)
      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new('feature_1', nil)
      decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('3324490562')
      status = user_context_obj.set_forced_decision(context, decision)
      expect(status).to be true
      status = user_context_obj.get_forced_decision(context)
      expect(status).to eq(decision)
      status = user_context_obj.remove_forced_decision(context)
      expect(status).to be true
      status = user_context_obj.remove_all_forced_decisions
      expect(status).to be true
    end

    it 'should set forced decision in decide' do
      impression_log_url = 'https://logx.optimizely.com/v1/events'
      time_now = Time.now
      post_headers = {'Content-Type' => 'application/json'}
      allow(Time).to receive(:now).and_return(time_now)
      allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')
      allow(forced_decision_project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      user_id = 'tester'
      feature_key = 'feature_1'
      expected_params = {
        account_id: '10367498574',
        project_id: '10431130345',
        revision: '241',
        client_name: 'ruby-sdk',
        client_version: Optimizely::VERSION,
        anonymize_ip: true,
        enrich_decisions: true,
        visitors: [{
          snapshots: [{
            events: [{
              entity_id: '',
              uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
              key: 'campaign_activated',
              timestamp: (time_now.to_f * 1000).to_i
            }],
            decisions: [{
              campaign_id: '',
              experiment_id: '',
              variation_id: '3324490562',
              metadata: {
                flag_key: 'feature_1',
                rule_key: '',
                rule_type: 'feature-test',
                variation_key: '3324490562',
                enabled: true
              }
            }]
          }],
          visitor_id: 'tester',
          attributes: [{
            entity_id: '$opt_bot_filtering',
            key: '$opt_bot_filtering',
            type: 'custom',
            value: true
          }]
        }]
      }
      stub_request(:post, impression_log_url)
      expect(forced_decision_project_instance.notification_center).to receive(:send_notifications)
        .once.with(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args)
      expect(forced_decision_project_instance.notification_center).to receive(:send_notifications)
        .with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'flag',
          'tester',
          {},
          flag_key: 'feature_1',
          enabled: true,
          variables: {
            'b_true' => true,
            'd_4_2' => 4.2,
            'i_1' => 'invalid',
            'i_42' => 42,
            'j_1' => {
              'value' => 1
            },
            's_foo' => 'foo'

          },
          variation_key: '3324490562',
          rule_key: nil,
          reasons: [],
          decision_event_dispatched: true
        )
      user_context_obj = forced_decision_project_instance.create_user_context(user_id)
      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, nil)
      forced_decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('3324490562')
      user_context_obj.set_forced_decision(context, forced_decision)
      decision = user_context_obj.decide(feature_key)
      expect(forced_decision_project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, expected_params, post_headers))
      expect(decision.variation_key).to eq('3324490562')
      expect(decision.rule_key).to be_nil
      expect(decision.enabled).to be true
      expect(decision.flag_key).to eq(feature_key)
      expect(decision.user_context.user_id).to eq(user_id)
      expect(decision.user_context.user_attributes.length).to eq(0)
      expect(decision.reasons).to eq([])
      expect(decision.user_context.forced_decisions.length).to eq(1)
      expect(decision.user_context.forced_decisions).to eq(context => forced_decision)
    end

    it 'should set experiment rule in forced decision using set forced decision' do
      impression_log_url = 'https://logx.optimizely.com/v1/events'
      time_now = Time.now
      post_headers = {'Content-Type' => 'application/json'}
      allow(Time).to receive(:now).and_return(time_now)
      allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')
      allow(forced_decision_project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      expected_params = {
        account_id: '10367498574',
        project_id: '10431130345',
        revision: '241',
        client_name: 'ruby-sdk',
        client_version: Optimizely::VERSION,
        anonymize_ip: true,
        enrich_decisions: true,
        visitors: [{
          snapshots: [{
            events: [{
              entity_id: '10420273888',
              uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
              key: 'campaign_activated',
              timestamp: (time_now.to_f * 1000).to_i
            }],
            decisions: [{
              campaign_id: '10420273888',
              experiment_id: '10390977673',
              variation_id: '10416523121',
              metadata: {
                flag_key: 'feature_1',
                rule_key: 'exp_with_audience',
                rule_type: 'feature-test',
                variation_key: 'b',
                enabled: false
              }
            }]
          }],
          visitor_id: 'tester',
          attributes: [{
            entity_id: '$opt_bot_filtering',
            key: '$opt_bot_filtering',
            type: 'custom',
            value: true
          }]
        }]
      }

      expect(forced_decision_project_instance.notification_center).to receive(:send_notifications)
        .with(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args)
      expect(forced_decision_project_instance.notification_center).to receive(:send_notifications)
        .with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'flag',
          'tester',
          {},
          flag_key: 'feature_1',
          enabled: false,
          variables: {
            'b_true' => true,
            'd_4_2' => 4.2,
            'i_1' => 'invalid',
            'i_42' => 42,
            'j_1' => {
              'value' => 1
            },
            's_foo' => 'foo'
          },
          variation_key: 'b',
          rule_key: 'exp_with_audience',
          reasons: ['Variation (b) is mapped to flag (feature_1), rule (exp_with_audience) and user (tester) in the forced decision map.'],
          decision_event_dispatched: true
        )
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'exp_with_audience')
      forced_decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('b')
      user_context_obj.set_forced_decision(context, forced_decision)
      decision = user_context_obj.decide(feature_key, [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
      expect(forced_decision_project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, expected_params, post_headers))
      expect(decision.variation_key).to eq('b')
      expect(decision.rule_key).to eq('exp_with_audience')
      expect(decision.enabled).to be false
      expect(decision.flag_key).to eq(feature_key)
      expect(decision.user_context.user_id).to eq(user_id)
      expect(decision.user_context.user_attributes.length).to eq(0)
      expect(decision.user_context.forced_decisions.length).to eq(1)
      expect(decision.user_context.forced_decisions).to eq(context => forced_decision)
      expect(decision.reasons).to eq(['Variation (b) is mapped to flag (feature_1), rule (exp_with_audience) and user (tester) in the forced decision map.'])
    end

    it 'should return an expected decision object when forced decision is called and variation of different experiment but same flag key' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'exp_with_audience')
      forced_decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('3324490633')
      user_context_obj.set_forced_decision(context, forced_decision)
      expected = expect do
        decision = user_context_obj.decide(feature_key, [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
        expect(decision.variation_key).to eq('3324490633')
        expect(decision.rule_key).to eq('exp_with_audience')
        expect(decision.enabled).to be false
        expect(decision.flag_key).to eq(feature_key)
        expect(decision.user_context.user_id).to eq(user_id)
        expect(decision.user_context.user_attributes.length).to eq(0)
        expect(decision.user_context.forced_decisions.length).to eq(1)
        expect(decision.user_context.forced_decisions).to eq(context => forced_decision)
        expect(decision.reasons).to eq(['Variation (3324490633) is mapped to flag (feature_1), rule (exp_with_audience) and user (tester) in the forced decision map.'])
      end
      expected.to raise_error
    end

    it 'should return correct variation if rule in forced decision is deleted' do
      impression_log_url = 'https://logx.optimizely.com/v1/events'
      time_now = Time.now
      post_headers = {'Content-Type' => 'application/json'}
      allow(Time).to receive(:now).and_return(time_now)
      allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')
      allow(forced_decision_project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      user_id = 'tester'
      feature_key = 'feature_1'
      expected_params = {
        account_id: '10367498574',
        project_id: '10431130345',
        revision: '241',
        client_name: 'ruby-sdk',
        client_version: Optimizely::VERSION,
        anonymize_ip: true,
        enrich_decisions: true,
        visitors: [{
          snapshots: [{
            events: [{
              entity_id: '',
              uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
              key: 'campaign_activated',
              timestamp: (time_now.to_f * 1000).to_i
            }],
            decisions: [{
              campaign_id: '',
              experiment_id: '',
              variation_id: '3324490562',
              metadata: {
                flag_key: 'feature_1',
                rule_key: '',
                rule_type: 'feature-test',
                variation_key: '3324490562',
                enabled: true
              }
            }]
          }],
          visitor_id: 'tester',
          attributes: [{
            entity_id: '$opt_bot_filtering',
            key: '$opt_bot_filtering',
            type: 'custom',
            value: true
          }]
        }]
      }
      stub_request(:post, impression_log_url)
      expect(forced_decision_project_instance.notification_center).to receive(:send_notifications)
        .once.with(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args)
      expect(forced_decision_project_instance.notification_center).to receive(:send_notifications)
        .with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'flag',
          'tester',
          {},
          flag_key: 'feature_1',
          enabled: true,
          variables: {
            'b_true' => true,
            'd_4_2' => 4.2,
            'i_1' => 'invalid',
            'i_42' => 42,
            'j_1' => {
              'value' => 1
            },
            's_foo' => 'foo'
          },
          variation_key: '3324490562',
          rule_key: nil,
          reasons: [],
          decision_event_dispatched: true
        )
      user_context_obj = forced_decision_project_instance.create_user_context(user_id)
      context_with_flag = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, nil)
      decision_for_flag = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('3324490562')
      context_with_rule = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'exp_with_audience')
      decision_for_rule = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('b')
      # set forced decision with flag
      user_context_obj.set_forced_decision(context_with_flag, decision_for_flag)
      # set forced decision with flag and rule
      user_context_obj.set_forced_decision(context_with_rule, decision_for_rule)
      # remove rule forced decision with flag
      user_context_obj.remove_forced_decision(context_with_rule)
      # decision should be based on flag forced decision
      decision = user_context_obj.decide(feature_key)
      expect(forced_decision_project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, expected_params, post_headers))
      expect(decision.variation_key).to eq('3324490562')
      expect(decision.rule_key).to be_nil
      expect(decision.enabled).to be true
      expect(decision.flag_key).to eq(feature_key)
      expect(decision.user_context.user_id).to eq(user_id)
      expect(decision.user_context.user_attributes.length).to eq(0)
      expect(decision.reasons).to eq([])
      expect(decision.user_context.forced_decisions.length).to eq(1)
      expect(decision.user_context.forced_decisions).to eq(context_with_flag => decision_for_flag)
    end

    it 'should set delivery rule in forced decision using set forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, '3332020515')
      forced_decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('3324490633')
      user_context_obj.set_forced_decision(context, forced_decision)
      decision = user_context_obj.decide(feature_key)
      expect(decision.variation_key).to eq('3324490633')
      expect(decision.rule_key).to eq('3332020515')
      expect(decision.enabled).to be true
      expect(decision.flag_key).to eq(feature_key)
      expect(decision.user_context.user_id).to eq(user_id)
      expect(decision.user_context.user_attributes.length).to eq(0)
      expect(decision.reasons).to eq([])
      expect(decision.user_context.forced_decisions.length).to eq(1)
      expect(decision.user_context.forced_decisions).to eq(context => forced_decision)

      decision = user_context_obj.decide(feature_key, [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
      expect(decision.reasons).to eq([
                                       "Starting to evaluate audience '13389141123' with conditions: [\"and\", [\"or\", [\"or\", {\"match\": \"exact\", \"name\": \"gender\", \"type\": \"custom_attribute\", \"value\": \"f\"}]]].",
                                       "Audience '13389141123' evaluated to UNKNOWN.",
                                       "Audiences for experiment 'exp_with_audience' collectively evaluated to FALSE.",
                                       "User 'tester' does not meet the conditions to be in experiment 'exp_with_audience'.",
                                       "The user 'tester' is not bucketed into any of the experiments on the feature 'feature_1'.",
                                       'Variation (3324490633) is mapped to flag (feature_1), rule (3332020515) and user (tester) in the forced decision map.'
                                     ])
    end

    it 'should return proper valid result for invalid variation in forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)

      # flag-to-decision
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, nil)
      decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('invalid')
      user_context_obj.set_forced_decision(context, decision)
      decision = user_context_obj.decide(feature_key, [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
      expect(decision.variation_key).to eq('18257766532')
      expect(decision.rule_key).to eq('18322080788')
      expect(decision.reasons).to include('Invalid variation is mapped to flag (feature_1) and user (tester) in the forced decision map.')

      # experiment-rule-to-decision
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'exp_with_audience')
      decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('invalid')
      user_context_obj.set_forced_decision(context, decision)
      decision = user_context_obj.decide(feature_key, [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
      expect(decision.variation_key).to eq('18257766532')
      expect(decision.rule_key).to eq('18322080788')
      expect(decision.reasons).to include('Invalid variation is mapped to flag (feature_1), rule (exp_with_audience) and user (tester) in the forced decision map.')

      # delivery-rule-to-decision
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, '3332020515')
      decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('invalid')
      user_context_obj.set_forced_decision(context, decision)
      decision = user_context_obj.decide(feature_key, [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
      expect(decision.variation_key).to eq('18257766532')
      expect(decision.rule_key).to eq('18322080788')
      expect(decision.reasons).to include("Starting to evaluate audience '13389141123' with conditions: [\"and\", [\"or\", [\"or\", {\"match\": \"exact\", \"name\": \"gender\", \"type\": \"custom_attribute\", \"value\": \"f\"}]]].")
    end

    it 'should return valid response with conflicts in forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      context_with_flag = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, nil)
      decision_for_flag = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('3324490562')
      context_with_rule = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'exp_with_audience')
      decision_for_rule = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('b')
      user_context_obj.set_forced_decision(context_with_flag, decision_for_flag)
      user_context_obj.set_forced_decision(context_with_rule, decision_for_rule)
      decision = user_context_obj.decide(feature_key)
      expect(decision.variation_key).to eq('3324490562')
      expect(decision.rule_key).to be_nil
    end

    it 'should get forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, nil)
      decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('fv1')
      user_context_obj.set_forced_decision(context, decision)
      expect(user_context_obj.get_forced_decision(context)).to eq(decision)

      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, nil)
      decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('fv2')
      user_context_obj.set_forced_decision(context, decision)
      expect(user_context_obj.get_forced_decision(context)).to eq(decision)

      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'r')
      decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('ev1')
      user_context_obj.set_forced_decision(context, decision)
      expect(user_context_obj.get_forced_decision(context)).to eq(decision)

      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'r')
      decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('ev2')
      user_context_obj.set_forced_decision(context, decision)
      expect(user_context_obj.get_forced_decision(context)).to eq(decision)

      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, nil)
      decision = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('fv2')
      expect(user_context_obj.get_forced_decision(context)).to eq(decision)
    end

    it 'should remove forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      context_with_flag = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, nil)
      decision_for_flag = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('fv1')
      user_context_obj.set_forced_decision(context_with_flag, decision_for_flag)

      context_with_rule = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'r')
      decision_for_rule = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('ev1')
      user_context_obj.set_forced_decision(context_with_rule, decision_for_rule)

      expect(user_context_obj.get_forced_decision(context_with_flag)).to eq(decision_for_flag)
      expect(user_context_obj.get_forced_decision(context_with_rule)).to eq(decision_for_rule)

      status = user_context_obj.remove_forced_decision(context_with_flag)
      expect(status).to be true
      expect(user_context_obj.get_forced_decision(context_with_flag)).to be_nil
      expect(user_context_obj.get_forced_decision(context_with_rule)).to eq(decision_for_rule)

      status = user_context_obj.remove_forced_decision(context_with_rule)
      expect(status).to be true
      expect(user_context_obj.get_forced_decision(context_with_flag)).to be_nil
      expect(user_context_obj.get_forced_decision(context_with_rule)).to be_nil

      status = user_context_obj.remove_forced_decision(context_with_flag)
      expect(status).to be false
    end

    it 'should remove all forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      context_with_flag = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, nil)
      decision_for_flag = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('fv1')

      context_with_rule = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'r')
      decision_for_rule = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('ev1')

      user_context_obj.set_forced_decision(context_with_flag, decision_for_flag)
      user_context_obj.set_forced_decision(context_with_rule, decision_for_rule)

      expect(user_context_obj.get_forced_decision(context_with_flag)).to eq(decision_for_flag)
      expect(user_context_obj.get_forced_decision(context_with_rule)).to eq(decision_for_rule)

      user_context_obj.remove_all_forced_decisions
      expect(user_context_obj.get_forced_decision(context_with_flag)).to be_nil
      expect(user_context_obj.get_forced_decision(context_with_rule)).to be_nil

      status = user_context_obj.remove_forced_decision(context_with_flag)
      expect(status).to be false
    end

    it 'should return valid variation for duplicate OptimizelyDecisionContext in forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)

      context_with_rule = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'r')
      decision_for_rule = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('ev1')

      context_with_rule_dup = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(feature_key, 'r')
      decision_for_rule_dup = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('dupv1')

      user_context_obj.set_forced_decision(context_with_rule, decision_for_rule)
      user_context_obj.set_forced_decision(context_with_rule_dup, decision_for_rule_dup)

      expect(user_context_obj.get_forced_decision(context_with_rule)).to eq(decision_for_rule_dup)
    end

    it 'should clone forced decision in user context' do
      user_id = 'tester'
      original_attributes = {'country' => 'us'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      user_clone_1 = user_context_obj.clone

      # with no forced decision
      expect(user_clone_1.user_id).to eq(user_id)
      expect(user_clone_1.user_attributes).to eq(original_attributes)
      expect(user_clone_1.forced_decisions).to be_empty

      context_with_flag = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new('a', nil)
      decision_for_flag = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('b')

      context_with_rule = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new('a', 'c')
      decision_for_rule = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('d')

      context_with_empty_rule = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new('a', '')
      decision_for_empty_rule = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('e')

      unassigned_context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new('x', nil)

      # with forced decisions
      user_context_obj.set_forced_decision(context_with_flag, decision_for_flag)
      user_context_obj.set_forced_decision(context_with_rule, decision_for_rule)
      user_context_obj.set_forced_decision(context_with_empty_rule, decision_for_empty_rule)

      user_clone_2 = user_context_obj.clone
      expect(user_clone_2.user_id).to eq(user_id)
      expect(user_clone_2.user_attributes).to eq(original_attributes)
      expect(user_clone_2.forced_decisions).not_to be_nil

      expect(user_clone_2.get_forced_decision(context_with_flag)).to eq(decision_for_flag)
      expect(user_clone_2.get_forced_decision(context_with_rule)).to eq(decision_for_rule)
      expect(user_clone_2.get_forced_decision(unassigned_context)).to be_nil
      expect(user_clone_2.get_forced_decision(context_with_empty_rule)).to eq(decision_for_empty_rule)

      context_with_rule = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new('a', 'new-rk')
      decision_for_rule = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('new-vk')
      # forced decisions should be copied separately
      user_context_obj.set_forced_decision(context_with_rule, decision_for_rule)
      expect(user_context_obj.get_forced_decision(context_with_rule)).to eq(decision_for_rule)
      expect(user_clone_2.get_forced_decision(context_with_rule)).to be_nil
    end

    it 'should set, get, remove, remove all and clone in synchronize manner' do
      user_id = 'tester'
      original_attributes = {}
      threads = []
      user_clone = nil
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      allow(user_context_obj).to receive(:clone)
      allow(user_context_obj).to receive(:set_forced_decision)
      allow(user_context_obj).to receive(:get_forced_decision)
      allow(user_context_obj).to receive(:remove_forced_decision)
      allow(user_context_obj).to receive(:remove_all_forced_decisions)

      context_with_flag_1 = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new('0', nil)
      decision_for_flag_1 = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('var')

      context_with_flag_2 = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new('1', nil)
      decision_for_flag_2 = Optimizely::OptimizelyUserContext::OptimizelyForcedDecision.new('var')

      # clone
      threads << Thread.new do
        100.times do
          user_clone = user_context_obj.clone
        end
      end

      # set forced decision
      threads << Thread.new do
        100.times do
          user_context_obj.set_forced_decision(context_with_flag_1, decision_for_flag_1)
        end
      end

      threads << Thread.new do
        100.times do
          user_context_obj.set_forced_decision(context_with_flag_2, decision_for_flag_2)
        end
      end

      # get forced decision
      threads << Thread.new do
        100.times do
          user_context_obj.get_forced_decision(context_with_flag_1)
        end
      end

      threads << Thread.new do
        100.times do
          user_context_obj.get_forced_decision(context_with_flag_2)
        end
      end

      # remove forced decision
      threads << Thread.new do
        100.times do
          user_context_obj.remove_forced_decision(context_with_flag_1)
        end
      end

      threads << Thread.new do
        100.times do
          user_context_obj.remove_forced_decision(context_with_flag_2)
        end
      end

      # remove all forced decision
      threads << Thread.new do
        user_context_obj.remove_all_forced_decisions
      end

      threads.each(&:join)
      expect(user_context_obj).to have_received(:clone).exactly(100).times
      expect(user_context_obj).to have_received(:set_forced_decision).with(context_with_flag_1, decision_for_flag_1).exactly(100).times
      expect(user_context_obj).to have_received(:set_forced_decision).with(context_with_flag_2, decision_for_flag_2).exactly(100).times
      expect(user_context_obj).to have_received(:get_forced_decision).with(context_with_flag_1).exactly(100).times
      expect(user_context_obj).to have_received(:get_forced_decision).with(context_with_flag_2).exactly(100).times
      expect(user_context_obj).to have_received(:remove_forced_decision).with(context_with_flag_1).exactly(100).times
      expect(user_context_obj).to have_received(:remove_forced_decision).with(context_with_flag_2).exactly(100).times
      expect(user_context_obj).to have_received(:remove_all_forced_decisions).once
    end
  end
  it 'should clone qualified segments in user context' do
    stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
    user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})
    qualified_segments = %w[seg1 seg2]
    user_context_obj.qualified_segments = qualified_segments
    user_clone_1 = user_context_obj.clone

    expect(user_clone_1.qualified_segments).not_to be_empty
    expect(user_clone_1.qualified_segments).to eq qualified_segments
    expect(user_clone_1.qualified_segments).not_to be user_context_obj.qualified_segments
    expect(user_clone_1.qualified_segments).not_to be qualified_segments
    integration_project_instance.close
  end

  it 'should hit segment in ab test' do
    stub_request(:post, impression_log_url)
    stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
    user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})
    user_context_obj.qualified_segments = %w[odp-segment-1 odp-segment-none]

    decision = user_context_obj.decide('flag-segment')

    expect(decision.variation_key).to eq 'variation-a'
    integration_project_instance.close
  end

  it 'should hit other audience with segments in ab test' do
    stub_request(:post, impression_log_url)
    stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
    user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', 'age' => 30)
    user_context_obj.qualified_segments = %w[odp-segment-none]

    decision = user_context_obj.decide('flag-segment', [Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE])

    expect(decision.variation_key).to eq 'variation-a'
    integration_project_instance.close
  end

  it 'should hit segment in rollout' do
    stub_request(:post, impression_log_url)
    stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
    user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})
    user_context_obj.qualified_segments = %w[odp-segment-2]

    decision = user_context_obj.decide('flag-segment', [Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE])

    expect(decision.variation_key).to eq 'rollout-variation-on'
    integration_project_instance.close
  end

  it 'should miss segment in rollout' do
    stub_request(:post, impression_log_url)
    stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
    user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})
    user_context_obj.qualified_segments = %w[odp-segment-none]

    decision = user_context_obj.decide('flag-segment', [Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE])

    expect(decision.variation_key).to eq 'rollout-variation-off'
    integration_project_instance.close
  end

  it 'should miss segment with empty segments' do
    stub_request(:post, impression_log_url)
    stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
    user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})
    user_context_obj.qualified_segments = []

    decision = user_context_obj.decide('flag-segment', [Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE])

    expect(decision.variation_key).to eq 'rollout-variation-off'
    integration_project_instance.close
  end

  it 'should not fail without any segments' do
    stub_request(:post, impression_log_url)
    stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
    user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})

    decision = user_context_obj.decide('flag-segment', [Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE])

    expect(decision.variation_key).to eq 'rollout-variation-off'
    integration_project_instance.close
  end

  it 'should send identify event when user context created' do
    stub_request(:post, 'https://api.zaius.com/v3/graphql').to_return(status: 200, body: good_response_data.to_json)
    stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
    expect(integration_project_instance.odp_manager).to receive(:identify_user).with({user_id: 'tester'})
    Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})

    integration_project_instance.close
  end

  describe '#fetch_qualified_segments' do
    it 'should fetch segments' do
      stub_request(:post, 'https://api.zaius.com/v3/graphql').to_return(status: 200, body: good_response_data.to_json)
      stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
      user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})

      segments = user_context_obj.fetch_qualified_segments

      expect(user_context_obj.qualified_segments).to eq %w[a b]
      expect(segments).to eq %w[a b]
      integration_project_instance.close
    end

    it 'should return empty array when not qualified for any segments' do
      good_response_data[:data][:customer][:audiences][:edges].map { |e| e[:node][:state] = 'unqualified' }

      stub_request(:post, 'https://api.zaius.com/v3/graphql').to_return(status: 200, body: good_response_data.to_json)
      stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
      user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})

      segments = user_context_obj.fetch_qualified_segments

      expect(user_context_obj.qualified_segments).to eq []
      expect(segments).to eq []
      integration_project_instance.close
    end

    it 'should fetch segments and reset cache' do
      stub_request(:post, 'https://api.zaius.com/v3/graphql').to_return(status: 200, body: good_response_data.to_json)
      stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
      segments_cache = integration_project_instance.odp_manager.instance_variable_get('@segment_manager').instance_variable_get('@segments_cache')
      segments_cache.save('wow', 'great')
      expect(segments_cache.lookup('wow')).to eq 'great'
      user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})

      segments = user_context_obj.fetch_qualified_segments([:RESET_CACHE])

      expect(segments_cache.lookup('wow')).to be_nil
      expect(user_context_obj.qualified_segments).to eq %w[a b]
      expect(segments).to eq %w[a b]
      integration_project_instance.close
    end

    it 'should fetch segments from cache' do
      stub_request(:post, 'https://api.zaius.com/v3/graphql').to_return(status: 200, body: good_response_data.to_json)
      stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)

      segment_manager = integration_project_instance.odp_manager.instance_variable_get('@segment_manager')
      cache_key = segment_manager.send(:make_cache_key, Optimizely::Helpers::Constants::ODP_MANAGER_CONFIG[:KEY_FOR_USER_ID], 'tester')

      segments_cache = segment_manager.instance_variable_get('@segments_cache')
      segments_cache.save(cache_key, %w[great])
      expect(segments_cache.lookup(cache_key)).to eq %w[great]

      user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})
      segments = user_context_obj.fetch_qualified_segments

      expect(user_context_obj.qualified_segments).to eq %w[great]
      expect(segments).to eq %w[great]
      integration_project_instance.close
    end

    it 'should fetch segments and ignore cache' do
      stub_request(:post, 'https://api.zaius.com/v3/graphql').to_return(status: 200, body: good_response_data.to_json)
      stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)

      segment_manager = integration_project_instance.odp_manager.instance_variable_get('@segment_manager')
      cache_key = segment_manager.send(:make_cache_key, Optimizely::Helpers::Constants::ODP_MANAGER_CONFIG[:KEY_FOR_USER_ID], 'tester')

      segments_cache = segment_manager.instance_variable_get('@segments_cache')
      segments_cache.save(cache_key, %w[great])
      expect(segments_cache.lookup(cache_key)).to eq %w[great]

      user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})
      segments = user_context_obj.fetch_qualified_segments([:IGNORE_CACHE])

      expect(user_context_obj.qualified_segments).to eq %w[a b]
      expect(segments).to eq %w[a b]
      expect(segments_cache.lookup(cache_key)).to eq %w[great]
      integration_project_instance.close
    end

    it 'should return nil on error' do
      stub_request(:post, 'https://api.zaius.com/v3/graphql').to_return(status: 500)
      stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
      user_context_obj = Optimizely::OptimizelyUserContext.new(integration_project_instance, 'tester', {})

      segments = user_context_obj.fetch_qualified_segments

      expect(user_context_obj.qualified_segments).to be_nil
      expect(segments).to be_nil
      integration_project_instance.close
    end
  end
end
