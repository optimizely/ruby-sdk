require 'json'
require 'spec_helper'

describe Optimizely::ConditionEvaluator do
  before(:context) do
    @config_body = OptimizelySpec::V1_CONFIG_BODY
  end

  before(:example) do
    user_attributes = {
      'browser_type' => 'firefox',
      'city' => 'san francisco'
    }
    @condition_evaluator = Optimizely::ConditionEvaluator.new(user_attributes)
  end

  it 'should return true for evaluator when there is a match' do
    condition_array = ['browser_type', 'firefox']
    expect(@condition_evaluator.evaluator(condition_array)).to be true
  end

  it 'should return false for evaluator when there is not a match' do
    condition_array = ['browser_type', 'chrome']
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
    condition = JSON.load(condition)
    expect(@condition_evaluator.evaluate(condition)).to be true
  end

  it 'should evaluate to false for evaluate when conditions evaluate to false' do
    condition = '["and", ["or", ["or", '\
                '{"name": "browser_type", "type": "custom_dimension", "value": "chrome"}]]]'
    condition = JSON.load(condition)
    expect(@condition_evaluator.evaluate(condition)).to be false
  end
end
