# frozen_string_literal: true

#
#    Copyright 2019, Optimizely and contributors
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
require 'optimizely/logger'

describe Optimizely::CustomAttributeConditionEvaluator do
  let(:spy_logger) { spy('logger') }

  it 'should return true when the attributes pass the audience conditions and no match type is provided' do
    condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'browser_type' => 'safari'}, spy_logger)
    expect(condition_evaluator.evaluate('name' => 'browser_type', 'type' => 'custom_attribute', 'value' => 'safari')).to be true
  end

  it 'should return false when the attributes pass the audience conditions and no match type is provided' do
    condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'browser_type' => 'firefox'}, spy_logger)
    expect(condition_evaluator.evaluate('name' => 'browser_type', 'type' => 'custom_attribute', 'value' => 'safari')).to be false
  end

  it 'should evaluate different typed attributes' do
    user_attributes = {
      'browser_type' => 'safari',
      'is_firefox' => true,
      'num_users' => 10,
      'pi_value' => 3.14
    }
    condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new(user_attributes, spy_logger)

    expect(condition_evaluator.evaluate('name' => 'browser_type', 'type' => 'custom_attribute', 'value' => 'safari')).to be true
    expect(condition_evaluator.evaluate('name' => 'is_firefox', 'type' => 'custom_attribute', 'value' => true)).to be true
    expect(condition_evaluator.evaluate('name' => 'num_users', 'type' => 'custom_attribute', 'value' => 10)).to be true
    expect(condition_evaluator.evaluate('name' => 'pi_value', 'type' => 'custom_attribute', 'value' => 3.14)).to be true
  end

  it 'should log and return nil when condition has an invalid type property' do
    condition = {'match' => 'exact', 'name' => 'weird_condition', 'type' => 'weird', 'value' => 'hi'}
    condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'weird_condition' => 'bye'}, spy_logger)
    expect(condition_evaluator.evaluate(condition)).to eq(nil)
    expect(spy_logger).to have_received(:log).exactly(1).times
    expect(spy_logger).to have_received(:log).once.with(
      Logger::WARN,
      "Audience condition #{condition} uses an unknown condition type. You may need to upgrade to a newer release of " \
      'the Optimizely SDK.'
    )
  end

  it 'should log and return nil when condition has no type property' do
    condition = {'match' => 'exact', 'name' => 'weird_condition', 'value' => 'hi'}
    condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'weird_condition' => 'bye'}, spy_logger)
    expect(condition_evaluator.evaluate(condition)).to eq(nil)
    expect(spy_logger).to have_received(:log).exactly(1).times
    expect(spy_logger).to have_received(:log).once.with(
      Logger::WARN,
      "Audience condition #{condition} uses an unknown condition type. You may need to upgrade to a newer release of " \
      'the Optimizely SDK.'
    )
  end

  it 'should log and return nil when condition has an invalid match property' do
    condition = {'match' => 'invalid', 'name' => 'browser_type', 'type' => 'custom_attribute', 'value' => 'chrome'}
    condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'browser_type' => 'chrome'}, spy_logger)
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
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({}, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be false
      expect(spy_logger).not_to have_received(:log)
    end

    it 'should return false if the user-provided value is nil' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => nil}, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be false
    end

    it 'should return true if the user-provided value is a string' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 'test'}, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be true
    end

    it 'should return true if the user-provided value is a number' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 10}, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be true

      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 10.0}, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be true
    end

    it 'should return true if the user-provided value is a boolean' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => false}, spy_logger)
      expect(condition_evaluator.evaluate(@exists_conditions)).to be true
    end
  end

  describe 'exact match type' do
    describe 'with a string condition value' do
      before(:context) do
        @exact_string_conditions = {'match' => 'exact', 'name' => 'location', 'type' => 'custom_attribute', 'value' => 'san francisco'}
      end

      it 'should return true if the user-provided value is equal to the condition value' do
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'location' => 'san francisco'}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to be true
      end

      it 'should return false if the user-provided value is not equal to the condition value' do
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'location' => 'new york'}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to be false
      end

      it 'should log and return nil if the user-provided value is of a different type than the condition value' do
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'location' => false}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to eq(nil)
        expect(spy_logger).to have_received(:log).once.with(
          Logger::WARN,
          "Audience condition #{@exact_string_conditions} evaluated as UNKNOWN because a value of type '#{false.class}' was passed for user attribute 'location'."
        )
      end

      it 'should log and return nil if there is no user-provided value' do
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to eq(nil)
        expect(spy_logger).to have_received(:log).once.with(
          Logger::DEBUG,
          "Audience condition #{@exact_string_conditions} evaluated as UNKNOWN because no value was passed for user attribute 'location'."
        )
      end

      it 'should log and return nil if the user-provided value is of a unexpected type' do
        # attribute value: nil
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'location' => []}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_string_conditions)).to eq(nil)
        expect(spy_logger).to have_received(:log).once.with(
          Logger::WARN,
          "Audience condition #{@exact_string_conditions} evaluated as UNKNOWN because a value of type 'Array' was " \
          "passed for user attribute 'location'."
        )

        # attribute value: empty hash
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'location' => {}}, spy_logger)
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
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'sum' => 100}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).to be true
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to be true

        # user-provided float value
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'sum' => 100.0}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).to be true
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to be true
      end

      it 'should return false if the user-provided value is not equal to the condition value' do
        # user-provided integer value
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'sum' => 101}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).to be false

        # user-provided float value
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'sum' => 100.1}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to be false
      end

      it 'should return nil if the user-provided value is of a different type than the condition value' do
        # user-provided boolean value
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'sum' => false}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).to eq(nil)
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to eq(nil)
      end

      it 'should return nil if there is no user-provided value' do
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).to eq(nil)
        expect(condition_evaluator.evaluate(@exact_float_conditions)).to eq(nil)
      end

      it 'should return nil when user-provided value is infinite' do
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'sum' => 1 / 0.0}, spy_logger)
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
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'sum' => 10}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_integer_conditions)).not_to be_nil
      end
    end

    describe 'with a boolean condition value' do
      before(:context) do
        @exact_boolean_conditions = {'match' => 'exact', 'name' => 'boolean', 'type' => 'custom_attribute', 'value' => false}
      end

      it 'should return true if the user-provided value is equal to the condition value' do
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'boolean' => false}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_boolean_conditions)).to be true
      end

      it 'should return false if the user-provided value is not equal to the condition value' do
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'boolean' => true}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_boolean_conditions)).to be false
      end

      it 'should return nil if the user-provided value is of a different type than the condition value' do
        # user-provided integer value
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'boolean' => 10}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_boolean_conditions)).to eq(nil)

        # user-provided float value
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'boolean' => 10.0}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_boolean_conditions)).to eq(nil)
      end

      it 'should return nil if there is no user-provided value' do
        condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({}, spy_logger)
        expect(condition_evaluator.evaluate(@exact_boolean_conditions)).to eq(nil)
      end
    end
  end

  describe 'substring match type' do
    before(:context) do
      @substring_conditions = {'match' => 'substring', 'name' => 'text', 'type' => 'custom_attribute', 'value' => 'test message!'}
    end

    it 'should return true if the condition value is a substring of the user-provided value' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'text' => 'This is a test message!'}, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to be true
    end

    it 'should return false if the user-provided value is not a substring of the condition value' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'text' => 'Not found!'}, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to be false
    end

    it 'should return nil if the user-provided value is not a string' do
      # user-provided integer value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'text' => 10}, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to eq(nil)

      # user-provided float value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'text' => 10.0}, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to eq(nil)
    end

    it 'should log and return nil if there is no user-provided value' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({}, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@substring_conditions} evaluated as UNKNOWN because no value was passed for user attribute 'text'."
      )
    end

    it 'should log and return nil if there user-provided value is of a unexpected type' do
      # attribute value: nil
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'text' => nil}, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@substring_conditions} evaluated to UNKNOWN because a nil value was passed for user attribute 'text'."
      )

      # attribute value: empty hash
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'text' => {}}, spy_logger)
      expect(condition_evaluator.evaluate(@substring_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@substring_conditions} evaluated as UNKNOWN because a value of type 'Hash' was " \
        "passed for user attribute 'text'."
      )
    end

    it 'should log and return nil when condition value is invalid' do
      @substring_conditions['value'] = 5
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'text' => 'This is a test message!'}, spy_logger)
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
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 12}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be true

      # user-provided float value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 12.0}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be true
    end

    it 'should return false if the user-provided value is equal to condition value' do
      # user-provided integer value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 10}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be false

      # user-provided float value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 10.0}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be false
    end

    it 'should return true if the user-provided value is less than the condition value' do
      # user-provided integer value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 8}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be false

      # user-provided float value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 8.0}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to be false
    end

    it 'should return nil if the user-provided value is not a number' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 'test'}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to eq(nil)
      expect(condition_evaluator.evaluate(@gt_float_conditions)).to eq(nil)
    end

    it 'should log and return nil if there is no user-provided value' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({}, spy_logger)
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
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => nil}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@gt_integer_conditions} evaluated to UNKNOWN because a nil value was passed for " \
        "user attribute 'input_value'."
      )

      # attribute value: empty hash
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => {}}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@gt_integer_conditions} evaluated as UNKNOWN because a value of type 'Hash' was " \
        "passed for user attribute 'input_value'."
      )
    end

    it 'should return nil when user-provided value is infinite' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 1 / 0.0}, spy_logger)
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
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 51}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).not_to be_nil
    end

    it 'should log and return nil when condition value is infinite' do
      @gt_integer_conditions['value'] = 1 / 0.0
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 51}, spy_logger)
      expect(condition_evaluator.evaluate(@gt_integer_conditions)).to be_nil
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@gt_integer_conditions} has an unsupported condition value. You may need to upgrade "\
            'to a newer release of the Optimizely SDK.'
      )
    end
  end

  describe 'less than match type' do
    before(:context) do
      @lt_integer_conditions = {'match' => 'lt', 'name' => 'input_value', 'type' => 'custom_attribute', 'value' => 10}
      @lt_float_conditions = {'match' => 'lt', 'name' => 'input_value', 'type' => 'custom_attribute', 'value' => 10.0}
    end

    it 'should return true if the user-provided value is less than the condition value' do
      # user-provided integer value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 8}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be true

      # user-provided float value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 8.0}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be true
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be true
    end

    it 'should return false if the user-provided value is equal to condition value' do
      # user-provided integer value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 10}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be false

      # user-provided float value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 10.0}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be false
    end

    it 'should return false if the user-provided value is greater than the condition value' do
      # user-provided integer value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 12}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be false

      # user-provided float value
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 12.0}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be false
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to be false
    end

    it 'should return nil if the user-provided value is not a number' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 'test'}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to eq(nil)
      expect(condition_evaluator.evaluate(@lt_float_conditions)).to eq(nil)
    end

    it 'should log and return nil if there is no user-provided value' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({}, spy_logger)
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
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => nil}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Audience condition #{@lt_integer_conditions} evaluated to UNKNOWN because a nil value was passed for " \
        "user attribute 'input_value'."
      )

      # attribute value: empty hash
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => {}}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@lt_integer_conditions} evaluated as UNKNOWN because a value of type 'Hash' was " \
        "passed for user attribute 'input_value'."
      )
    end

    it 'should return nil when user-provided value is infinite' do
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 1 / 0.0}, spy_logger)
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
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 75}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).not_to be_nil
    end

    it 'should log and return nil when condition value is infinite' do
      @lt_integer_conditions['value'] = 1 / 0.0
      condition_evaluator = Optimizely::CustomAttributeConditionEvaluator.new({'input_value' => 51}, spy_logger)
      expect(condition_evaluator.evaluate(@lt_integer_conditions)).to be_nil
      expect(spy_logger).to have_received(:log).once.with(
        Logger::WARN,
        "Audience condition #{@lt_integer_conditions} has an unsupported condition value. You may need to upgrade "\
          'to a newer release of the Optimizely SDK.'
      )
    end
  end
end
