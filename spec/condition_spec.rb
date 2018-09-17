# frozen_string_literal: true

#
#    Copyright 2016-2018, Optimizely and contributors
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
require 'json'
require 'spec_helper'

describe Optimizely::ConditionEvaluator do
  before(:context) do
    @config_body = OptimizelySpec::VALID_CONFIG_BODY
  end

  before(:example) do
    user_attributes = {
      'browser_type' => 'firefox',
      'city' => 'san francisco'
    }
    @condition_evaluator = Optimizely::ConditionEvaluator.new(user_attributes)
  end

  it 'should return true for evaluator when there is a match' do
    condition_array = %w[browser_type firefox]
    expect(@condition_evaluator.evaluator(condition_array)).to be true
  end

  it 'should return false for evaluator when there is not a match' do
    condition_array = %w[browser_type chrome]
    expect(@condition_evaluator.evaluator(condition_array)).to be false
  end

  it 'should return true for and_evaluator when all conditions evaluate to true' do
    conditions = [
      {
        'name' => 'browser_type',
        'type' => 'custom_dimension',
        'value' => 'firefox'
      }, {
        'name' => 'city',
        'type' => 'custom_dimension',
        'value' => 'san francisco'
      }
    ]
    expect(@condition_evaluator.and_evaluator(conditions)).to be true
  end

  it 'should return false for and_evaluator when any one condition evaluates to false' do
    conditions = [
      {
        'name' => 'browser_type',
        'type' => 'custom_dimension',
        'value' => 'firefox'
      }, {
        'name' => 'city',
        'type' => 'custom_dimension',
        'value' => 'new york'
      }
    ]
    expect(@condition_evaluator.and_evaluator(conditions)).to be false
  end

  it 'should return true for or_evaluator when any one condition evaluates to true' do
    conditions = [
      {
        'name' => 'browser_type',
        'type' => 'custom_dimension',
        'value' => 'firefox'
      }, {
        'name' => 'city',
        'type' => 'custom_dimension',
        'value' => 'new york'
      }
    ]
    expect(@condition_evaluator.or_evaluator(conditions)).to be true
  end

  it 'should return false for or_evaluator when all conditions evaluate to false' do
    conditions = [
      {
        'name' => 'browser_type',
        'type' => 'custom_dimension',
        'value' => 'chrome'
      }, {
        'name' => 'city',
        'type' => 'custom_dimension',
        'value' => 'new york'
      }
    ]
    expect(@condition_evaluator.or_evaluator(conditions)).to be false
  end

  it 'should return true for not_evaluator when condition evaluates to false' do
    conditions = [
      {
        'name' => 'browser_type',
        'type' => 'custom_dimension',
        'value' => 'chrome'
      }
    ]
    expect(@condition_evaluator.not_evaluator(conditions)).to be true
  end

  it 'should return false for not_evaluator when condition evaluates to true' do
    conditions = [
      {
        'name' => 'browser_type',
        'type' => 'custom_dimension',
        'value' => 'firefox'
      }
    ]
    expect(@condition_evaluator.not_evaluator(conditions)).to be false
  end

  it 'should return false for not_evaluator when array has more than one condition' do
    expect(@condition_evaluator.not_evaluator([42, 42])).to be false
  end

  it 'should return true for evaluate when conditions evaluate to true' do
    condition = @config_body['audiences'][0]['conditions']
    condition = JSON.parse(condition)
    expect(@condition_evaluator.evaluate(condition)).to be true
  end

  it 'should evaluate to false for evaluate when conditions evaluate to false' do
    condition = '["and", ["or", ["or", '\
                '{"name": "browser_type", "type": "custom_dimension", "value": "chrome"}]]]'
    condition = JSON.parse(condition)
    expect(@condition_evaluator.evaluate(condition)).to be false
  end

  it 'should evaluate to true for evaluate when NOT conditions evaluate to true' do
    condition = '["not", {"name": "browser_type", "type": "custom_dimension", "value": "chrome"}]'
    condition = JSON.parse(condition)
    expect(@condition_evaluator.evaluate(condition)).to be true
  end

  it 'should evaluate to true for evaluate when user attributes evaluate true' do
    user_attributes = {
      'device_type' => 'iPhone',
      'is_firefox' => false,
      'num_users' => 15,
      'pi_value' => 3.14
    }
    condition_evaluator = Optimizely::ConditionEvaluator.new(user_attributes)
    condition = '["and", ["or", ["or", {"name": "device_type", "type": "custom_attribute", "value": "iPhone"}]],
    ["or", ["or", {"name": "is_firefox", "type": "custom_attribute", "value": false}]], ["or", ["or", {"name": "num_users",
      "type": "custom_attribute", "value": 15}]], ["or", ["or", {"name": "pi_value", "type": "custom_attribute", "value": 3.14}]]]'
    condition = JSON.parse(condition)
    expect(condition_evaluator.evaluate(condition)).to be true
  end
end
