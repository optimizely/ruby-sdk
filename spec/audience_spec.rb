# frozen_string_literal: true

#
#    Copyright 2016-2017, 2019, Optimizely and contributors
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
  before(:context) do
    @config_body = OptimizelySpec::VALID_CONFIG_BODY
    @config_body_json = OptimizelySpec::VALID_CONFIG_BODY_JSON
    @config_typed_audience_json = JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES)
  end

  before(:example) do
    @project_instance = Optimizely::Project.new(@config_body_json)
    @project_typed_audience_instance = Optimizely::Project.new(@config_typed_audience_json)
  end

  it 'should return true for user_in_experiment? when experiment is using no audience' do
    user_attributes = {}
    # Both Audience Ids and Conditions are Empty
    experiment = @project_instance.config.experiment_key_map['test_experiment']
    experiment['audienceIds'] = []
    experiment['audienceConditions'] = []

    expect(Optimizely::Audience.user_in_experiment?(@project_instance.config,
                                                    experiment,
                                                    user_attributes)).to be true

    # Audience Ids exist but Audience Conditions is Empty
    experiment = @project_instance.config.experiment_key_map['test_experiment']
    experiment['audienceIds'] = ['11154']
    experiment['audienceConditions'] = []

    expect(Optimizely::Audience.user_in_experiment?(@project_instance.config,
                                                    experiment,
                                                    user_attributes)).to be true

    # Audience Ids is Empty and  Audience Conditions is nil
    experiment = @project_instance.config.experiment_key_map['test_experiment']
    experiment['audienceIds'] = []
    experiment['audienceConditions'] = nil

    expect(Optimizely::Audience.user_in_experiment?(@project_instance.config,
                                                    experiment,
                                                    user_attributes)).to be true
  end

  it 'should pass conditions when audience conditions exist else audienceIds are passed' do
    user_attributes = {'test_attribute' => 'test_value_1'}
    experiment = @project_instance.config.experiment_key_map['test_experiment']
    experiment['audienceIds'] = ['11154']
    allow(Optimizely::ConditionTreeEvaluator).to receive(:evaluate)

    # Both Audience Ids and Conditions exist
    experiment['audienceConditions'] = ['and', %w[or 3468206642 3988293898], %w[or 3988293899 3468206646 3468206647 3468206644 3468206643]]
    Optimizely::Audience.user_in_experiment?(@project_instance.config,
                                             experiment,
                                             user_attributes)
    expect(Optimizely::ConditionTreeEvaluator).to have_received(:evaluate).with(experiment['audienceConditions'], any_args).once

    # Audience Ids exist but Audience Conditions is nil
    experiment['audienceConditions'] = nil
    Optimizely::Audience.user_in_experiment?(@project_instance.config,
                                             experiment,
                                             user_attributes)
    expect(Optimizely::ConditionTreeEvaluator).to have_received(:evaluate).with(experiment['audienceIds'], any_args).once
  end

  it 'should return false for user_in_experiment? if there are audiences but nil or empty attributes' do
    experiment = @project_instance.config.experiment_key_map['test_experiment_with_audience']
    allow(Optimizely::CustomAttributeConditionEvaluator).to receive(:new).and_call_original

    # attributes set to empty dict
    expect(Optimizely::Audience.user_in_experiment?(@project_instance.config,
                                                    experiment,
                                                    {})).to be false
    # attributes set to nil
    expect(Optimizely::Audience.user_in_experiment?(@project_instance.config,
                                                    experiment,
                                                    nil)).to be false
    # asserts nil attributes default to empty dict
    expect(Optimizely::CustomAttributeConditionEvaluator).to have_received(:new).with({}).twice
  end

  it 'should return true for user_in_experiment? when condition tree evaluator returns true' do
    experiment = @project_instance.config.experiment_key_map['test_experiment']
    user_attributes = {
      'test_attribute' => 'test_value_1'
    }
    allow(Optimizely::ConditionTreeEvaluator).to receive(:evaluate).and_return(true)
    expect(Optimizely::Audience.user_in_experiment?(@project_instance.config,
                                                    experiment,
                                                    user_attributes)).to be true
  end

  it 'should return false for user_in_experiment? when condition tree evaluator returns false or nil' do
    experiment = @project_instance.config.experiment_key_map['test_experiment_with_audience']
    user_attributes = {
      'browser_type' => 'firefox'
    }

    # condition tree evaluator returns nil
    allow(Optimizely::ConditionTreeEvaluator).to receive(:evaluate).and_return(nil)
    expect(Optimizely::Audience.user_in_experiment?(@project_instance.config,
                                                    experiment,
                                                    user_attributes)).to be false

    # condition tree evaluator returns false
    allow(Optimizely::ConditionTreeEvaluator).to receive(:evaluate).and_return(false)
    expect(Optimizely::Audience.user_in_experiment?(@project_instance.config,
                                                    experiment,
                                                    user_attributes)).to be false
  end

  it 'should correctly evaluate audience Ids and call custom attribute evaluator for leaf nodes' do
    experiment = @project_instance.config.experiment_key_map['test_experiment_with_audience']
    user_attributes = {
      'browser_type' => 'firefox'
    }
    experiment['audienceIds'] = %w[11154 11155]
    experiment['audienceConditions'] = nil

    audience_11154 = @project_instance.config.get_audience_from_id('11154')
    audience_11155 = @project_instance.config.get_audience_from_id('11155')
    audience_11154_condition = JSON.parse(audience_11154['conditions'])[1][1][1]
    audience_11155_condition = JSON.parse(audience_11155['conditions'])[1][1][1]

    customer_attr = Optimizely::CustomAttributeConditionEvaluator.new(user_attributes)
    allow(customer_attr).to receive(:exact_evaluator)
    customer_attr.evaluate(audience_11154_condition)
    customer_attr.evaluate(audience_11155_condition)

    expect(customer_attr).to have_received(:exact_evaluator).with(audience_11154_condition).once
    expect(customer_attr).to have_received(:exact_evaluator).with(audience_11155_condition).once
  end

  it 'should correctly evaluate audienceConditions and call custom attribute evaluator for leaf nodes' do
    experiment = @project_typed_audience_instance.config.get_experiment_from_key('audience_combinations_experiment')
    experiment['audienceIds'] = []
    experiment['audienceConditions'] = ['or', %w[or 3468206642 3988293898], %w[or 3988293899 3468206646]]

    audience_3468206642 = @project_typed_audience_instance.config.get_audience_from_id('3468206642')
    audience_3988293898 = @project_typed_audience_instance.config.get_audience_from_id('3988293898')
    audience_3988293899 = @project_typed_audience_instance.config.get_audience_from_id('3988293899')
    audience_3468206646 = @project_typed_audience_instance.config.get_audience_from_id('3468206646')

    audience_3468206642_condition = JSON.parse(audience_3468206642['conditions'])[1][1][1]
    audience_3988293898_condition = audience_3988293898['conditions'][1][1][1]
    audience_3988293899_condition = audience_3988293899['conditions'][1][1][1]
    audience_3468206646_condition = audience_3468206646['conditions'][1][1][1]

    customer_attr = Optimizely::CustomAttributeConditionEvaluator.new({})
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
    experiment = @project_typed_audience_instance.config.get_experiment_from_key('audience_combinations_experiment')
    experiment['audienceConditions'] = '3468206645'
    customer_attr = Optimizely::CustomAttributeConditionEvaluator.new({})

    audience_3468206645 = @project_typed_audience_instance.config.get_audience_from_id('3468206645')
    audience_3468206645_condition1 = audience_3468206645['conditions'][1][1][1]
    audience_3468206645_condition2 = audience_3468206645['conditions'][1][1][2]
    allow(customer_attr).to receive(:exact_evaluator)
    customer_attr.evaluate(audience_3468206645_condition1)
    customer_attr.evaluate(audience_3468206645_condition2)

    expect(customer_attr).to have_received(:exact_evaluator).with(audience_3468206645_condition1).once
    expect(customer_attr).to have_received(:exact_evaluator).with(audience_3468206645_condition2).once
  end
end
