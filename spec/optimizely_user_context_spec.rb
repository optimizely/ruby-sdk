# frozen_string_literal: true

#
#    Copyright 2020, Optimizely and contributors
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
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_instance) { Optimizely::Project.new(config_body_JSON, nil, spy_logger, error_handler) }
  let(:forced_decision_project_instance) { Optimizely::Project.new(forced_decision_JSON, nil, spy_logger, error_handler) }
  let(:impression_log_url) { 'https://logx.optimizely.com/v1/events' }

  describe '#initialize' do
    it 'should set passed value as expected' do
      user_id = 'test_user'
      attributes = {' browser' => 'firefox'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, attributes)

      expect(user_context_obj.instance_variable_get(:@optimizely_client)). to eq(project_instance)
      expect(user_context_obj.instance_variable_get(:@user_id)). to eq(user_id)
      expect(user_context_obj.instance_variable_get(:@user_attributes)). to eq(attributes)
    end

    it 'should set user attributes to empty hash when passed nil' do
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, 'test_user', nil)
      expect(user_context_obj.instance_variable_get(:@user_attributes)). to eq({})
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
      expect(user_context_obj.instance_variable_get(:@user_attributes)). to eq(expected_attributes)
    end

    it 'should override attribute value if key already exists in hash' do
      user_id = 'test_user'
      attributes = {' browser' => 'firefox', 'color' => ' red'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, attributes)
      user_context_obj.set_attribute('browser', 'chrome')

      expected_attributes = attributes
      expected_attributes['browser'] = 'chrome'

      expect(user_context_obj.instance_variable_get(:@user_attributes)). to eq(expected_attributes)
    end

    it 'should not alter original attributes object when attrubute is modified in the user context' do
      user_id = 'test_user'
      original_attributes = {'browser' => 'firefox'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, original_attributes)
      user_context_obj.set_attribute('id', 49)
      expect(user_context_obj.instance_variable_get(:@user_attributes)). to eq(
        'browser' => 'firefox',
        'id' => 49
      )
      expect(original_attributes).to eq('browser' => 'firefox')
    end
  end

  describe '#forced_decisions' do
    it 'should return invalid status for invalid datafile in forced decision calls' do
      user_id = 'test_user'
      original_attributes = {}
      invalid_project_instance = Optimizely::Project.new('Invalid datafile', nil, spy_logger, error_handler)
      user_context_obj = Optimizely::OptimizelyUserContext.new(invalid_project_instance, user_id, original_attributes)
      status = user_context_obj.set_forced_decision('feature_1', '3324490562')
      expect(status).to be false
      status = user_context_obj.get_forced_decision('feature_1')
      expect(status).to be_nil
      status = user_context_obj.remove_forced_decision('feature_1')
      expect(status).to be false
      status = user_context_obj.remove_all_forced_decision
      expect(status).to be false
    end

    it 'should return status for datafile in forced decision calls' do
      user_id = 'test_user'
      original_attributes = {}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, original_attributes)
      status = user_context_obj.set_forced_decision('feature_1', '3324490562')
      expect(status).to be true
      status = user_context_obj.get_forced_decision('feature_1')
      expect(status).to eq('3324490562')
      status = user_context_obj.remove_forced_decision('feature_1')
      expect(status).to be true
      status = user_context_obj.remove_all_forced_decision
      expect(status).to be true
    end

    it 'should set forced decision in decide' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      user_context_obj.set_forced_decision(feature_key, '3324490562')
      decision = user_context_obj.decide(feature_key)
      expect(decision.variation_key).to eq('3324490562')
      expect(decision.rule_key).to be_nil
      expect(decision.enabled).to be true
      expect(decision.flag_key).to eq(feature_key)
      expect(decision.user_context.user_id).to eq(user_id)
      expect(decision.user_context.user_attributes.length).to eq(0)
      expect(decision.reasons).to eq([])
      expect(decision.user_context.forced_decisions.length).to eq(1)
      expect(decision.user_context.forced_decisions).to eq(Optimizely::OptimizelyUserContext::ForcedDecision.new(feature_key, nil) => '3324490562')

      decision = user_context_obj.decide(feature_key, [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
      expect(decision.reasons).to eq(['Variation (3324490562) is mapped to flag (feature_1) and user (tester) in the forced decision map.'])
    end

    it 'should set experiment rule in forced decision using set forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      user_context_obj.set_forced_decision(feature_key, 'exp_with_audience', 'b')
      decision = user_context_obj.decide(feature_key)
      expect(decision.variation_key).to eq('b')
      expect(decision.rule_key).to eq('exp_with_audience')
      expect(decision.enabled).to be false
      expect(decision.flag_key).to eq(feature_key)
      expect(decision.user_context.user_id).to eq(user_id)
      expect(decision.user_context.user_attributes.length).to eq(0)
      expect(decision.reasons).to eq([])
      expect(decision.user_context.forced_decisions.length).to eq(1)
      expect(decision.user_context.forced_decisions).to eq(Optimizely::OptimizelyUserContext::ForcedDecision.new(feature_key, 'exp_with_audience') => 'b')

      decision = user_context_obj.decide(feature_key, [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
      expect(decision.reasons).to eq(['Variation (b) is mapped to flag (feature_1), rule (exp_with_audience) and user (tester) in the forced decision map.'])
    end

    it 'should set delivery rule in forced decision using set forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      user_context_obj.set_forced_decision(feature_key, '3332020515', '3324490633')
      decision = user_context_obj.decide(feature_key)
      expect(decision.variation_key).to eq('3324490633')
      expect(decision.rule_key).to eq('3332020515')
      expect(decision.enabled).to be true
      expect(decision.flag_key).to eq(feature_key)
      expect(decision.user_context.user_id).to eq(user_id)
      expect(decision.user_context.user_attributes.length).to eq(0)
      expect(decision.reasons).to eq([])
      expect(decision.user_context.forced_decisions.length).to eq(1)
      expect(decision.user_context.forced_decisions).to eq(Optimizely::OptimizelyUserContext::ForcedDecision.new(feature_key, '3332020515') => '3324490633')

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
      user_context_obj.set_forced_decision(feature_key, 'invalid')
      decision = user_context_obj.decide(feature_key, [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
      expect(decision.variation_key).to eq('18257766532')
      expect(decision.rule_key).to eq('18322080788')
      expect(decision.reasons).to include('Invalid variation is mapped to flag (feature_1) and user (tester) in the forced decision map.')

      # experiment-rule-to-decision
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      user_context_obj.set_forced_decision(feature_key, 'exp_with_audience', 'invalid')
      decision = user_context_obj.decide(feature_key, [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
      expect(decision.variation_key).to eq('18257766532')
      expect(decision.rule_key).to eq('18322080788')
      expect(decision.reasons).to include('Invalid variation is mapped to flag (feature_1), rule (exp_with_audience) and user (tester) in the forced decision map.')

      # delivery-rule-to-decision
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      user_context_obj.set_forced_decision(feature_key, '3332020515', 'invalid')
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
      user_context_obj.set_forced_decision(feature_key, '3324490562')
      user_context_obj.set_forced_decision(feature_key, 'exp_with_audience', 'b')
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
      user_context_obj.set_forced_decision(feature_key, 'fv1')
      expect(user_context_obj.get_forced_decision(feature_key)).to eq('fv1')

      user_context_obj.set_forced_decision(feature_key, 'fv2')
      expect(user_context_obj.get_forced_decision(feature_key)).to eq('fv2')

      user_context_obj.set_forced_decision(feature_key, 'r', 'ev1')
      expect(user_context_obj.get_forced_decision(feature_key, 'r')).to eq('ev1')

      user_context_obj.set_forced_decision(feature_key, 'r', 'ev2')
      expect(user_context_obj.get_forced_decision(feature_key, 'r')).to eq('ev2')

      expect(user_context_obj.get_forced_decision(feature_key)).to eq('fv2')
    end

    it 'should remove forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      user_context_obj.set_forced_decision(feature_key, 'fv1')
      user_context_obj.set_forced_decision(feature_key, 'r', 'ev1')

      expect(user_context_obj.get_forced_decision(feature_key)).to eq('fv1')
      expect(user_context_obj.get_forced_decision(feature_key, 'r')).to eq('ev1')

      status = user_context_obj.remove_forced_decision(feature_key)
      expect(status).to be true
      expect(user_context_obj.get_forced_decision(feature_key)).to be_nil
      expect(user_context_obj.get_forced_decision(feature_key, 'r')).to eq('ev1')

      status = user_context_obj.remove_forced_decision(feature_key, 'r')
      expect(status).to be true
      expect(user_context_obj.get_forced_decision(feature_key)).to be_nil
      expect(user_context_obj.get_forced_decision(feature_key, 'r')).to be_nil

      status = user_context_obj.remove_forced_decision(feature_key)
      expect(status).to be false
    end

    it 'should remove all forced decision' do
      user_id = 'tester'
      feature_key = 'feature_1'
      original_attributes = {}
      stub_request(:post, impression_log_url)
      user_context_obj = Optimizely::OptimizelyUserContext.new(forced_decision_project_instance, user_id, original_attributes)
      user_context_obj.set_forced_decision(feature_key, 'fv1')
      user_context_obj.set_forced_decision(feature_key, 'r', 'ev1')

      expect(user_context_obj.get_forced_decision(feature_key)).to eq('fv1')
      expect(user_context_obj.get_forced_decision(feature_key, 'r')).to eq('ev1')

      user_context_obj.remove_all_forced_decision
      expect(user_context_obj.get_forced_decision(feature_key)).to be_nil
      expect(user_context_obj.get_forced_decision(feature_key, 'r')).to be_nil

      status = user_context_obj.remove_forced_decision(feature_key)
      expect(status).to be false
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

      # with forced decisions
      user_context_obj.set_forced_decision('a', 'b')
      user_context_obj.set_forced_decision('a', 'c', 'd')

      user_clone_2 = user_context_obj.clone
      expect(user_clone_2.user_id).to eq(user_id)
      expect(user_clone_2.user_attributes).to eq(original_attributes)
      expect(user_clone_2.forced_decisions).not_to be_nil

      expect(user_clone_2.get_forced_decision('a')).to eq('b')
      expect(user_clone_2.get_forced_decision('a', 'c')).to eq('d')
      expect(user_clone_2.get_forced_decision('x')).to be_nil

      # forced decisions should be copied separately
      user_context_obj.set_forced_decision('a', 'new-rk', 'new-vk')
      expect(user_context_obj.get_forced_decision('a', 'new-rk')).to eq('new-vk')
      expect(user_clone_2.get_forced_decision('a', 'new-rk')).to be_nil
    end
  end
end
