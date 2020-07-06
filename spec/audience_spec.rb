# frozen_string_literal: true

#
#    Copyright 2016-2017, 2019-2020, Optimizely and contributors
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
describe Optimizely::Audience do
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:config_typed_audience_JSON) { JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES) }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:typed_audience_config) { Optimizely::DatafileProjectConfig.new(config_typed_audience_JSON, spy_logger, error_handler) }

  it 'should return true for user_meets_audience_conditions? when experiment is using no audience' do
    user_attributes = {}
    # Both Audience Ids and Conditions are Empty
    experiment = config.experiment_key_map['test_experiment']
    experiment['audienceIds'] = []
    experiment['audienceConditions'] = []

    expect(Optimizely::Audience.user_meets_audience_conditions?(config,
                                                                experiment,
                                                                user_attributes,
                                                                spy_logger)).to be true

    # Audience Ids exist but Audience Conditions is Empty
    experiment = config.experiment_key_map['test_experiment']
    experiment['audienceIds'] = ['11154']
    experiment['audienceConditions'] = []

    expect(Optimizely::Audience.user_meets_audience_conditions?(config,
                                                                experiment,
                                                                user_attributes,
                                                                spy_logger)).to be true

    # Audience Ids is Empty and  Audience Conditions is nil
    experiment = config.experiment_key_map['test_experiment']
    experiment['audienceIds'] = []
    experiment['audienceConditions'] = nil

    expect(Optimizely::Audience.user_meets_audience_conditions?(config,
                                                                experiment,
                                                                user_attributes,
                                                                spy_logger)).to be true
  end

  it 'should pass conditions when audience conditions exist else audienceIds are passed' do
    user_attributes = {'test_attribute' => 'test_value_1'}
    experiment = config.experiment_key_map['test_experiment']
    experiment['audienceIds'] = ['11154']
    allow(Optimizely::ConditionTreeEvaluator).to receive(:evaluate)

    # Both Audience Ids and Conditions exist
    experiment['audienceConditions'] = ['and', %w[or 3468206642 3988293898], %w[or 3988293899 3468206646 3468206647 3468206644 3468206643]]
    Optimizely::Audience.user_meets_audience_conditions?(config,
                                                         experiment,
                                                         user_attributes,
                                                         spy_logger)
    expect(Optimizely::ConditionTreeEvaluator).to have_received(:evaluate).with(experiment['audienceConditions'], any_args).once

    # Audience Ids exist but Audience Conditions is nil
    experiment['audienceConditions'] = nil
    Optimizely::Audience.user_meets_audience_conditions?(config,
                                                         experiment,
                                                         user_attributes,
                                                         spy_logger)
    expect(Optimizely::ConditionTreeEvaluator).to have_received(:evaluate).with(experiment['audienceIds'], any_args).once
  end

  it 'should return false for user_meets_audience_conditions? if there are audiences but nil or empty attributes' do
    experiment = config.experiment_key_map['test_experiment_with_audience']
    allow(Optimizely::CustomAttributeConditionEvaluator).to receive(:new).and_call_original

    # attributes set to empty dict
    expect(Optimizely::Audience.user_meets_audience_conditions?(config,
                                                                experiment,
                                                                {},
                                                                spy_logger)).to be false
    # attributes set to nil
    expect(Optimizely::Audience.user_meets_audience_conditions?(config,
                                                                experiment,
                                                                nil,
                                                                spy_logger)).to be false
    # asserts nil attributes default to empty dict
    expect(Optimizely::CustomAttributeConditionEvaluator).to have_received(:new).with({}, spy_logger).twice
  end

  it 'should return true for user_meets_audience_conditions? when condition tree evaluator returns true' do
    experiment = config.experiment_key_map['test_experiment']
    user_attributes = {
      'test_attribute' => 'test_value_1'
    }
    allow(Optimizely::ConditionTreeEvaluator).to receive(:evaluate).and_return(true)
    expect(Optimizely::Audience.user_meets_audience_conditions?(config,
                                                                experiment,
                                                                user_attributes,
                                                                spy_logger)).to be true
  end

  it 'should return false for user_meets_audience_conditions? when condition tree evaluator returns false or nil' do
    experiment = config.experiment_key_map['test_experiment_with_audience']
    user_attributes = {
      'browser_type' => 'firefox'
    }

    # condition tree evaluator returns nil
    allow(Optimizely::ConditionTreeEvaluator).to receive(:evaluate).and_return(nil)
    expect(Optimizely::Audience.user_meets_audience_conditions?(config,
                                                                experiment,
                                                                user_attributes,
                                                                spy_logger)).to be false

    # condition tree evaluator returns false
    allow(Optimizely::ConditionTreeEvaluator).to receive(:evaluate).and_return(false)
    expect(Optimizely::Audience.user_meets_audience_conditions?(config,
                                                                experiment,
                                                                user_attributes,
                                                                spy_logger)).to be false
  end

  it 'should correctly evaluate audience Ids and call custom attribute evaluator for leaf nodes' do
    experiment = config.experiment_key_map['test_experiment_with_audience']
    user_attributes = {
      'browser_type' => 'firefox'
    }
    experiment['audienceIds'] = %w[11154 11155]
    experiment['audienceConditions'] = nil

    audience_11154 = config.get_audience_from_id('11154')
    audience_11155 = config.get_audience_from_id('11155')
    audience_11154_condition = JSON.parse(audience_11154['conditions'])[1][1][1]
    audience_11155_condition = JSON.parse(audience_11155['conditions'])[1][1][1]

    customer_attr = Optimizely::CustomAttributeConditionEvaluator.new(user_attributes, spy_logger)
    allow(customer_attr).to receive(:exact_evaluator)
    customer_attr.evaluate(audience_11154_condition)
    customer_attr.evaluate(audience_11155_condition)

    expect(customer_attr).to have_received(:exact_evaluator).with(audience_11154_condition).once
    expect(customer_attr).to have_received(:exact_evaluator).with(audience_11155_condition).once
  end

  it 'should correctly evaluate audienceConditions and call custom attribute evaluator for leaf nodes' do
    user_attributes = {
      'house' => 'Gryffindor',
      'lasers' => 45.5
    }
    experiment = typed_audience_config.get_experiment_from_key('audience_combinations_experiment')
    experiment['audienceIds'] = []
    experiment['audienceConditions'] = ['or', %w[or 3468206642 3988293898], %w[or 3988293899 3468206646]]

    audience_3468206642 = typed_audience_config.get_audience_from_id('3468206642')
    audience_3988293898 = typed_audience_config.get_audience_from_id('3988293898')
    audience_3988293899 = typed_audience_config.get_audience_from_id('3988293899')
    audience_3468206646 = typed_audience_config.get_audience_from_id('3468206646')

    audience_3468206642_condition = JSON.parse(audience_3468206642['conditions'])[1][1][1]
    audience_3988293898_condition = audience_3988293898['conditions'][1][1][1]
    audience_3988293899_condition = audience_3988293899['conditions'][1][1][1]
    audience_3468206646_condition = audience_3468206646['conditions'][1][1][1]

    customer_attr = Optimizely::CustomAttributeConditionEvaluator.new(user_attributes, spy_logger)
    allow(customer_attr).to receive(:exact_evaluator)
    allow(customer_attr).to receive(:substring_evaluator)
    allow(customer_attr).to receive(:exists_evaluator)
    customer_attr.evaluate(audience_3468206642_condition)
    customer_attr.evaluate(audience_3988293898_condition)
    customer_attr.evaluate(audience_3988293899_condition)
    customer_attr.evaluate(audience_3468206646_condition)

    expect(customer_attr).to have_received(:exact_evaluator).with(audience_3468206642_condition).once
    expect(customer_attr).to have_received(:substring_evaluator).with(audience_3988293898_condition).once
    expect(customer_attr).to have_received(:exists_evaluator).with(audience_3988293899_condition).once
    expect(customer_attr).to have_received(:exact_evaluator).with(audience_3468206646_condition).once
  end

  it 'should correctly evaluate leaf node in audienceConditions' do
    user_attributes = {
      'browser' => 'chrome'
    }
    experiment = typed_audience_config.get_experiment_from_key('audience_combinations_experiment')
    experiment['audienceConditions'] = '3468206645'
    customer_attr = Optimizely::CustomAttributeConditionEvaluator.new(user_attributes, spy_logger)

    audience_3468206645 = typed_audience_config.get_audience_from_id('3468206645')
    audience_3468206645_condition1 = audience_3468206645['conditions'][1][1][1]
    audience_3468206645_condition2 = audience_3468206645['conditions'][1][1][2]
    allow(customer_attr).to receive(:exact_evaluator)
    customer_attr.evaluate(audience_3468206645_condition1)
    customer_attr.evaluate(audience_3468206645_condition2)

    expect(customer_attr).to have_received(:exact_evaluator).with(audience_3468206645_condition1).once
    expect(customer_attr).to have_received(:exact_evaluator).with(audience_3468206645_condition2).once
  end

  it 'should return nil when audience not found' do
    experiment = config.experiment_key_map['test_experiment_with_audience']
    user_attributes = {
      'browser_type' => 5.5
    }
    experiment['audienceIds'] = %w[11110]

    expect(Optimizely::Audience.user_meets_audience_conditions?(config,
                                                                experiment,
                                                                user_attributes,
                                                                spy_logger)).to be false
    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Evaluating audiences for experiment 'test_experiment_with_audience': " + '["11110"].'
    )

    expect(spy_logger).to have_received(:log).once.with(
      Logger::INFO,
      "Audiences for experiment 'test_experiment_with_audience' collectively evaluated to FALSE."
    )
  end

  it 'should log and return false for user_meets_audience_conditions? evaluates audienceIds' do
    experiment = config.experiment_key_map['test_experiment_with_audience']
    user_attributes = {
      'browser_type' => 5.5
    }
    experiment['audienceIds'] = %w[11154 11155]
    experiment['audienceConditions'] = nil

    expect(Optimizely::Audience.user_meets_audience_conditions?(config,
                                                                experiment,
                                                                user_attributes,
                                                                spy_logger)).to be false
    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Evaluating audiences for experiment 'test_experiment_with_audience': " + '["11154", "11155"].'
    )

    # audience_11154
    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Starting to evaluate audience '11154' with conditions: "\
      '["and", ["or", ["or", {"name": "browser_type", "type": "custom_attribute", "value": "firefox"}]]].'
    )

    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Audience '11154' evaluated to UNKNOWN."
    )

    # audience_11155
    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Starting to evaluate audience '11155' with conditions: "\
      '["and", ["or", ["or", {"name": "browser_type", "type": "custom_attribute", "value": "chrome"}]]].'
    )

    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Audience '11155' evaluated to UNKNOWN."
    )

    expect(spy_logger).to have_received(:log).once.with(
      Logger::INFO,
      "Audiences for experiment 'test_experiment_with_audience' collectively evaluated to FALSE."
    )
  end

  it 'should log and return true for user_meets_audience_conditions? evaluates audienceConditions' do
    user_attributes = {
      'lasers' => 45.5
    }
    experiment = typed_audience_config.get_experiment_from_key('audience_combinations_experiment')
    experiment['audienceIds'] = []
    experiment['audienceConditions'] = ['or', %w[or 3468206647 3988293898 3468206646]]

    Optimizely::Audience.user_meets_audience_conditions?(typed_audience_config, experiment, user_attributes, spy_logger)

    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Evaluating audiences for experiment 'audience_combinations_experiment': "\
       '["or", ["or", "3468206647", "3988293898", "3468206646"]].'
    ).ordered # Order: 0

    # audience_3468206647
    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Starting to evaluate audience '3468206647' with conditions: "\
      '["and", ["or", ["or", {"name"=>"lasers", "type"=>"custom_attribute", "match"=>"gt", "value"=>70}]]].'
    ).ordered # Order: 1

    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Audience '3468206647' evaluated to FALSE."
    ).ordered # Order: 2

    # audience_3988293898
    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Starting to evaluate audience '3988293898' with conditions: "\
      '["and", ["or", ["or", {"name"=>"house", "type"=>"custom_attribute", "match"=>"substring", "value"=>"Slytherin"}]]].'
    ).ordered # Order: 3

    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Audience '3988293898' evaluated to UNKNOWN."
    ).ordered # Order: 4

    # audience_3468206646
    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Starting to evaluate audience '3468206646' with conditions: "\
      '["and", ["or", ["or", {"name"=>"lasers", "type"=>"custom_attribute", "match"=>"exact", "value"=>45.5}]]].'
    ).ordered # Order: 5

    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Audience '3468206646' evaluated to TRUE."
    ).ordered # Order: 6

    expect(spy_logger).to have_received(:log).once.with(
      Logger::INFO,
      "Audiences for experiment 'audience_combinations_experiment' collectively evaluated to TRUE."
    ).ordered # Order: 7
  end

  it 'should log using logging_hash and logging_key when provided' do
    logging_hash = 'ROLLOUT_AUDIENCE_EVALUATION_LOGS'
    logging_key = 'some_key'

    user_attributes = {
      'lasers' => 45.5
    }
    experiment = typed_audience_config.get_experiment_from_key('audience_combinations_experiment')
    experiment['audienceIds'] = []
    experiment['audienceConditions'] = ['or', %w[or 3468206647 3988293898 3468206646]]

    Optimizely::Audience.user_meets_audience_conditions?(typed_audience_config, experiment, user_attributes, spy_logger, logging_hash, logging_key)

    expect(spy_logger).to have_received(:log).once.with(
      Logger::DEBUG,
      "Evaluating audiences for rule 'some_key': "\
       '["or", ["or", "3468206647", "3988293898", "3468206646"]].'
    )

    expect(spy_logger).to have_received(:log).once.with(
      Logger::INFO,
      "Audiences for rule 'some_key' collectively evaluated to TRUE."
    )
  end
end
