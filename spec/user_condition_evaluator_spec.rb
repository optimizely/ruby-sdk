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
require 'json'
require 'spec_helper'
require 'optimizely/helpers/validator'
require 'optimizely/event/forwarding_event_processor'
require 'optimizely/event_dispatcher'
require 'optimizely/logger'

describe Optimizely::UserConditionEvaluator do
  let(:spy_logger) { spy('logger') }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:event_processor) { Optimizely::ForwardingEventProcessor.new(Optimizely::EventDispatcher.new) }
  let(:project_instance) { Optimizely::Project.new(config_body_JSON, nil, spy_logger, error_handler, false, nil, nil, nil, nil, event_processor) }
  let(:user_context) { project_instance.create_user_context('some-user', {}) }
  after(:example) { project_instance.close }

  it 'should return true when the attributes pass the audience conditions and no match type is provided' do
    user_context.instance_variable_set(:@user_attributes, 'browser_type' => 'safari')
    condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
    expect(condition_evaluator.evaluate('name' => 'browser_type', 'type' => 'custom_attribute', 'value' => 'safari')).to be true
  end

  it 'should return false when the attributes pass the audience conditions and no match type is provided' do
    user_context.instance_variable_set(:@user_attributes, 'browser_type' => 'firefox')
    condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
    expect(condition_evaluator.evaluate('name' => 'browser_type', 'type' => 'custom_attribute', 'value' => 'safari')).to be false
  end

  it 'should evaluate different typed attributes' do
    user_attributes = {
      'browser_type' => 'safari',
      'is_firefox' => true,
      'num_users' => 10,
      'pi_value' => 3.14
    }
    user_context.instance_variable_set(:@user_attributes, user_attributes)
    condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)

    expect(condition_evaluator.evaluate('name' => 'browser_type', 'type' => 'custom_attribute', 'value' => 'safari')).to be true
    expect(condition_evaluator.evaluate('name' => 'is_firefox', 'type' => 'custom_attribute', 'value' => true)).to be true
    expect(condition_evaluator.evaluate('name' => 'num_users', 'type' => 'custom_attribute', 'value' => 10)).to be true
    expect(condition_evaluator.evaluate('name' => 'pi_value', 'type' => 'custom_attribute', 'value' => 3.14)).to be true
  end

  it 'should log and return nil when condition has an invalid type property' do
    condition = {'match' => 'exact', 'name' => 'weird_condition', 'type' => 'weird', 'value' => 'hi'}
    user_context.instance_variable_set(:@user_attributes, 'weird_condition' => 'bye')
    condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
    expect(condition_evaluator.evaluate(condition)).to eq(nil)
    expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    expect(spy_logger).to have_received(:log).once.with(
      Logger::WARN,
      "Audience condition #{condition} uses an unknown condition type. You may need to upgrade to a newer release of " \
      'the Optimizely SDK.'
    )
  end

  it 'should log and return nil when condition has no type property' do
    condition = {'match' => 'exact', 'name' => 'weird_condition', 'value' => 'hi'}
    user_context.instance_variable_set(:@user_attributes, 'weird_condition' => 'bye')
    condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
    expect(condition_evaluator.evaluate(condition)).to eq(nil)
    expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    expect(spy_logger).to have_received(:log).once.with(
      Logger::WARN,
      "Audience condition #{condition} uses an unknown condition type. You may need to upgrade to a newer release of " \
      'the Optimizely SDK.'
    )
  end

  it 'should log and return nil when condition has an invalid match property' do
    condition = {'match' => 'invalid', 'name' => 'browser_type', 'type' => 'custom_attribute', 'value' => 'chrome'}
    user_context.instance_variable_set(:@user_attributes, 'browser_type' => 'chrome')
    condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
    expect(condition_evaluator.evaluate(condition)).to eq(nil)
    expect(spy_logger).to have_received(:log).once.with(
      Logger::WARN,
      "Audience condition #{condition} uses an unknown match type. You may need to upgrade to a newer release " \
      'of the Optimizely SDK.'
    )
  end

  describe 'exists match type' do
    before(:context) do
      @exists_conditions = {'match' => 'exists', 'name' => 'input_value', 'type' => 'custom_attribute'}
    end

    it 'should return false if there is no user-provided value' do
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be false
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).not_to have_received(:log).with(Logger::WARN, anything)
    end

    it 'should return false if the user-provided value is nil' do
      user_context.instance_variable_set(:@user_attributes, 'input_value' => nil)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be false
    end

    it 'should return true if the user-provided value is a string' do
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 'test')
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be true
    end

    it 'should return true if the user-provided value is a number' do
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 10)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be true

      user_context.instance_variable_set(:@user_attributes, 'input_value' => 10.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be true
    end

    it 'should return true if the user-provided value is a boolean' do
      user_context.instance_variable_set(:@user_attributes, 'input_value' => false)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be true
    end
  end

  describe 'exact match type' do
    describe 'with a string condition value' do
      before(:context) do
        @exact_string_conditions = {'match' => 'exact', 'name' => 'location', 'type' => 'custom_attribute', 'value' => 'san francisco'}
      end

      it 'should return true if the user-provided value is equal to the condition value' do
        user_context.instance_variable_set(:@user_attributes, 'location' => 'san francisco')
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to be true
      end

      it 'should return false if the user-provided value is not equal to the condition value' do
        user_context.instance_variable_set(:@user_attributes, 'location' => 'new york')
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to be false
      end

      it 'should log and return nil if the user-provided value is of a different type than the condition value' do
        user_context.instance_variable_set(:@user_attributes, 'location' => false)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to eq(nil)
        expect(spy_logger).to have_received(:log).once.with(
          Logger::WARN,
          "Audience condition #{@exact_string_conditions} evaluated as UNKNOWN because a value of type '#{false.class}' was passed for user attribute 'location'."
        )
      end

      it 'should log and return nil if there is no user-provided value' do
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to eq(nil)
        expect(spy_logger).to have_received(:log).once.with(
          Logger::DEBUG,
          "Audience condition #{@exact_string_conditions} evaluated as UNKNOWN because no value was passed for user attribute 'location'."
        )
      end

      it 'should log and return nil if the user-provided value is of a unexpected type' do
        # attribute value: nil
        user_context.instance_variable_set(:@user_attributes, 'location' => [])
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to eq(nil)
        expect(spy_logger).to have_received(:log).once.with(
          Logger::WARN,
          "Audience condition #{@exact_string_conditions} evaluated as UNKNOWN because a value of type 'Array' was " \
          "passed for user attribute 'location'."
        )

        # attribute value: empty hash
        user_context.instance_variable_set(:@user_attributes, 'location' => {})
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to eq(nil)
        expect(spy_logger).to have_received(:log).once.with(
          Logger::WARN,
          "Audience condition #{@exact_string_conditions} evaluated as UNKNOWN because a value of type 'Hash' was " \
          "passed for user attribute 'location'."
        )
      end
    end

    describe 'with a number condition value' do
      before(:context) do
        @exact_integer_conditions = {'match' => 'exact', 'name' => 'sum', 'type' => 'custom_attribute', 'value' => 100}
        @exact_float_conditions = {'match' => 'exact', 'name' => 'sum', 'type' => 'custom_attribute', 'value' => 100.0}
      end

      it 'should return true if the user-provided value is equal to the condition value' do
        # user-provided integer value
        user_context.instance_variable_set(:@user_attributes, 'sum' => 100)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).to be true
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to be true

        # user-provided float value
        user_context.instance_variable_set(:@user_attributes, 'sum' => 100.0)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).to be true
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to be true
      end

      it 'should return false if the user-provided value is not equal to the condition value' do
        # user-provided integer value
        user_context.instance_variable_set(:@user_attributes, 'sum' => 101)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).to be false

        # user-provided float value
        user_context.instance_variable_set(:@user_attributes, 'sum' => 100.1)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to be false
      end

      it 'should return nil if the user-provided value is of a different type than the condition value' do
        # user-provided boolean value
        user_context.instance_variable_set(:@user_attributes, 'sum' => false)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).to eq(nil)
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to eq(nil)
      end

      it 'should return nil if there is no user-provided value' do
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).to eq(nil)
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to eq(nil)
      end

      it 'should return nil when user-provided value is infinite' do
        user_context.instance_variable_set(:@user_attributes, 'sum' => 1 / 0.0)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to be nil

        expect(spy_logger).to have_received(:log).once.with(
          Logger::WARN,
          "Audience condition #{@exact_float_conditions} evaluated to UNKNOWN because the number value for " \
              "user attribute 'sum' is not in the range [-2^53, +2^53]."
        )
      end

      it 'should not return nil when finite_number? returns true for provided arguments' do
        @exact_integer_conditions['value'] = 10
        allow(Optimizely::Helpers::Validator).to receive(:finite_number?).twice.and_return(true, true)
        user_context.instance_variable_set(:@user_attributes, 'sum' => 10)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).not_to be_nil
      end
    end

    describe 'with a boolean condition value' do
      before(:context) do
        @exact_boolean_conditions = {'match' => 'exact', 'name' => 'boolean', 'type' => 'custom_attribute', 'value' => false}
      end

      it 'should return true if the user-provided value is equal to the condition value' do
        user_context.instance_variable_set(:@user_attributes, 'boolean' => false)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_boolean_conditions)).to be true
      end

      it 'should return false if the user-provided value is not equal to the condition value' do
        user_context.instance_variable_set(:@user_attributes, 'boolean' => true)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_boolean_conditions)).to be false
      end

      it 'should return nil if the user-provided value is of a different type than the condition value' do
        # user-provided integer value
        user_context.instance_variable_set(:@user_attributes, 'boolean' => 10)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_boolean_conditions)).to eq(nil)

        # user-provided float value
        user_context.instance_variable_set(:@user_attributes, 'boolean' => 10.0)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_boolean_conditions)).to eq(nil)
      end

      it 'should return nil if there is no user-provided value' do
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@exact_boolean_conditions)).to eq(nil)
      end
    end
  end

  describe 'substring match type' do
    before(:context) do
      @substring_conditions = {'match' => 'substring', 'name' => 'text', 'type' => 'custom_attribute', 'value' => 'test message!'}
    end

    it 'should return true if the condition value is a substring of the user-provided value' do
      user_context.instance_variable_set(:@user_attributes, 'text' => 'This is a test message!')
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to be true
    end

    it 'should return false if the user-provided value is not a substring of the condition value' do
      user_context.instance_variable_set(:@user_attributes, 'text' => 'Not found!')
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to be false
    end

    it 'should return nil if the user-provided value is not a string' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'text' => 10)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to eq(nil)

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'text' => 10.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to eq(nil)
    end

    it 'should log and return nil if there is no user-provided value' do
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@substring_conditions} evaluated as UNKNOWN because no value was passed for user attribute 'text'."
      )
    end

    it 'should log and return nil if there user-provided value is of a unexpected type' do
      # attribute value: nil
      user_context.instance_variable_set(:@user_attributes, 'text' => nil)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@substring_conditions} evaluated to UNKNOWN because a nil value was passed for user attribute 'text'."
      )

      # attribute value: empty hash
      user_context.instance_variable_set(:@user_attributes, 'text' => {})
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@substring_conditions} evaluated as UNKNOWN because a value of type 'Hash' was " \
        "passed for user attribute 'text'."
      )
    end

    it 'should log and return nil when condition value is invalid' do
      @substring_conditions['value'] = 5
      user_context.instance_variable_set(:@user_attributes, 'text' => 'This is a test message!')
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to be_nil
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@substring_conditions} has an unsupported condition value. You may need to upgrade "\
          'to a newer release of the Optimizely SDK.'
      )
    end
  end

  describe 'greater than match type' do
    before(:context) do
      @gt_integer_conditions = {'match' => 'gt', 'name' => 'input_value', 'type' => 'custom_attribute', 'value' => 10}
      @gt_float_conditions = {'match' => 'gt', 'name' => 'input_value', 'type' => 'custom_attribute', 'value' => 10.0}
    end

    it 'should return true if the user-provided value is greater than the condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 12)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be true

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 12.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be true
    end

    it 'should return false if the user-provided value is equal to condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 10)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be false

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 10.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be false
    end

    it 'should return true if the user-provided value is less than the condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 8)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be false

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 8.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be false
    end

    it 'should return nil if the user-provided value is not a number' do
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 'test')
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to eq(nil)
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to eq(nil)
    end

    it 'should log and return nil if there is no user-provided value' do
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to eq(nil)
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@gt_integer_conditions} evaluated as UNKNOWN because no value was passed for user attribute 'input_value'."
      )
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@gt_float_conditions} evaluated as UNKNOWN because no value was passed for user attribute 'input_value'."
      )
    end

    it 'should log and return nil if there user-provided value is of a unexpected type' do
      # attribute value: nil
      user_context.instance_variable_set(:@user_attributes, 'input_value' => nil)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@gt_integer_conditions} evaluated to UNKNOWN because a nil value was passed for " \
        "user attribute 'input_value'."
      )

      # attribute value: empty hash
      user_context.instance_variable_set(:@user_attributes, 'input_value' => {})
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@gt_integer_conditions} evaluated as UNKNOWN because a value of type 'Hash' was " \
        "passed for user attribute 'input_value'."
      )
    end

    it 'should return nil when user-provided value is infinite' do
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 1 / 0.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@gt_integer_conditions} evaluated to UNKNOWN because the number value for " \
          "user attribute 'input_value' is not in the range [-2^53, +2^53]."
      )
    end

    it 'should not return nil when finite_number? returns true for provided arguments' do
      @gt_integer_conditions['value'] = 81
      allow(Optimizely::Helpers::Validator).to receive(:finite_number?).twice.and_return(true, true)
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 51)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).not_to be_nil
    end

    it 'should log and return nil when condition value is infinite' do
      @gt_integer_conditions['value'] = 1 / 0.0
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 51)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be_nil
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@gt_integer_conditions} has an unsupported condition value. You may need to upgrade "\
            'to a newer release of the Optimizely SDK.'
      )
    end
  end

  describe 'greater than or equal match type' do
    before(:context) do
      @gt_integer_conditions = {'match' => 'ge', 'name' => 'input_value', 'type' => 'custom_attribute', 'value' => 10}
      @gt_float_conditions = {'match' => 'ge', 'name' => 'input_value', 'type' => 'custom_attribute', 'value' => 10.0}
    end

    it 'should return true if the user-provided value is greater than the condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 12)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be true

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 12.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be true
    end

    it 'should return true if the user-provided value is equal to condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 10)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be true

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 10.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be true
    end

    it 'should return false if the user-provided value is less than the condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 8)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be false

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 8.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be false
    end
  end

  describe 'less than match type' do
    before(:context) do
      @lt_integer_conditions = {'match' => 'lt', 'name' => 'input_value', 'type' => 'custom_attribute', 'value' => 10}
      @lt_float_conditions = {'match' => 'lt', 'name' => 'input_value', 'type' => 'custom_attribute', 'value' => 10.0}
    end

    it 'should return true if the user-provided value is less than the condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 8)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be true

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 8.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be true
    end

    it 'should return false if the user-provided value is equal to condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 10)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be false

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 10.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be false
    end

    it 'should return false if the user-provided value is greater than the condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 12)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be false

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 12.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be false
    end

    it 'should return nil if the user-provided value is not a number' do
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 'test')
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to eq(nil)
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to eq(nil)
    end

    it 'should log and return nil if there is no user-provided value' do
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to eq(nil)
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@lt_integer_conditions} evaluated as UNKNOWN because no value was passed for user attribute 'input_value'."
      )
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@lt_float_conditions} evaluated as UNKNOWN because no value was passed for user attribute 'input_value'."
      )
    end

    it 'should log and return nil if there user-provided value is of a unexpected type' do
      # attribute value: nil
      user_context.instance_variable_set(:@user_attributes, 'input_value' => nil)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@lt_integer_conditions} evaluated to UNKNOWN because a nil value was passed for " \
        "user attribute 'input_value'."
      )

      # attribute value: empty hash
      user_context.instance_variable_set(:@user_attributes, 'input_value' => {})
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@lt_integer_conditions} evaluated as UNKNOWN because a value of type 'Hash' was " \
        "passed for user attribute 'input_value'."
      )
    end

    it 'should return nil when user-provided value is infinite' do
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 1 / 0.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@lt_integer_conditions} evaluated to UNKNOWN because the number value for " \
          "user attribute 'input_value' is not in the range [-2^53, +2^53]."
      )
    end

    it 'should not return nil when finite_number? returns true for provided arguments' do
      @lt_integer_conditions['value'] = 65
      allow(Optimizely::Helpers::Validator).to receive(:finite_number?).twice.and_return(true, true)
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 75)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).not_to be_nil
    end

    it 'should log and return nil when condition value is infinite' do
      @lt_integer_conditions['value'] = 1 / 0.0
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 51)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be_nil
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@lt_integer_conditions} has an unsupported condition value. You may need to upgrade "\
          'to a newer release of the Optimizely SDK.'
      )
    end
  end

  describe 'less than or equal match type' do
    before(:context) do
      @lt_integer_conditions = {'match' => 'le', 'name' => 'input_value', 'type' => 'custom_attribute', 'value' => 10}
      @lt_float_conditions = {'match' => 'le', 'name' => 'input_value', 'type' => 'custom_attribute', 'value' => 10.0}
    end

    it 'should return false if the user-provided value is greater than the condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 12)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be false

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 12.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be false
    end

    it 'should return true if the user-provided value is equal to condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 10)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be true

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 10.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be true
    end

    it 'should return true if the user-provided value is less than the condition value' do
      # user-provided integer value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 8)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be true

      # user-provided float value
      user_context.instance_variable_set(:@user_attributes, 'input_value' => 8.0)
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be true
    end
  end

  describe 'semver_equal_evaluator' do
    before(:context) do
      @semver_condition = {'match' => 'semver_eq', 'name' => 'version', 'type' => 'custom_attribute', 'value' => '2.0'}
    end

    ['2.0.0', '2.0'].each do |version|
      it "should return true for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be true
      end
    end

    ['2.9', '1.9'].each do |version|
      it "should return false for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be false
      end
    end
  end

  describe 'semver_less_than_or_equal_evaluator ' do
    before(:context) do
      @semver_condition = {'match' => 'semver_le', 'name' => 'version', 'type' => 'custom_attribute', 'value' => '2.0'}
    end

    ['2.0.0', '1.9'].each do |version|
      it "should return true for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be true
      end
    end

    ['2.5.1'].each do |version|
      it "should return false for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be false
      end
    end
  end

  describe 'semver_greater_than_or_equal_evaluator ' do
    before(:context) do
      @semver_condition = {'match' => 'semver_ge', 'name' => 'version', 'type' => 'custom_attribute', 'value' => '2.0'}
    end

    ['2.0.0', '2.9'].each do |version|
      it "should return true for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be true
      end
    end

    ['1.9'].each do |version|
      it "should return false for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be false
      end
    end
  end

  describe 'semver_less_than_evaluator ' do
    before(:context) do
      @semver_condition = {'match' => 'semver_lt', 'name' => 'version', 'type' => 'custom_attribute', 'value' => '2.0'}
    end

    ['1.9'].each do |version|
      it "should return true for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be true
      end
    end

    ['2.0.0', '2.5.1'].each do |version|
      it "should return false for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be false
      end
    end
  end

  describe 'semver_greater_than_evaluator ' do
    before(:context) do
      @semver_condition = {'match' => 'semver_gt', 'name' => 'version', 'type' => 'custom_attribute', 'value' => '2.0'}
    end

    ['2.9'].each do |version|
      it "should return true for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be true
      end
    end

    ['2.0.0', '1.9'].each do |version|
      it "should return false for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be false
      end
    end
  end

  describe 'semver invalid type' do
    before(:context) do
      @semver_condition = {'match' => 'semver_eq', 'name' => 'version', 'type' => 'custom_attribute', 'value' => '2.0'}
    end

    # version not string
    [true, 37].each do |version|
      it "should return nil for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be nil
        expect(spy_logger).to have_received(:log).once.with(
          Logger::WARN,
          "Audience condition #{@semver_condition} evaluated as UNKNOWN because a value of type '#{version.class}' was passed for user attribute 'version'."
        )
      end
    end

    # invalid semantic version
    ['3.7.2.2', '+'].each do |version|
      it "should return nil for user version #{version}" do
        user_context.instance_variable_set(:@user_attributes, 'version' => version)
        condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
        expect(condition_evaluator.evaluate(@semver_condition)).to be nil
        expect(spy_logger).to have_received(:log).once.with(
          Logger::WARN,
          "Audience condition #{@semver_condition} evaluated as UNKNOWN because an invalid semantic version was passed for user attribute 'version'."
        )
      end
    end
  end
  describe 'qualified match type' do
    before(:context) do
      @qualified_conditions = {'match' => 'qualified', 'name' => 'odp.audiences', 'type' => 'third_party_dimension', 'value' => 'odp-segment-2'}
    end

    it 'should return true when user is qualified' do
      user_context.qualified_segments = ['odp-segment-2']
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@qualified_conditions)).to be true
    end

    it 'should return false when user is not qualified' do
      user_context.qualified_segments = ['odp-segment-1']
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@qualified_conditions)).to be false
    end

    it 'should return false with no qualified segments' do
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@qualified_conditions)).to be false
    end

    it 'should return true when name is different' do
      @qualified_conditions['name'] = 'other-name'
      user_context.qualified_segments = ['odp-segment-2']
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@qualified_conditions)).to be true
    end

    it 'should log and return nil when condition value is invalid' do
      @qualified_conditions['value'] = 5
      user_context.instance_variable_set(:@user_attributes, 'text' => 'This is a test message!')
      condition_evaluator = Optimizely::UserConditionEvaluator.new(user_context, spy_logger)
      expect(condition_evaluator.evaluate(@qualified_conditions)).to be_nil
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@qualified_conditions} has an unsupported condition value. You may need to upgrade "\
          'to a newer release of the Optimizely SDK.'
      )
    end
  end
end
