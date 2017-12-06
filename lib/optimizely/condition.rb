# frozen_string_literal: true

#
#    Copyright 2016, Optimizely and contributors
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

module Optimizely
  class ConditionalOperatorTypes
    AND = 'and'
    OR = 'or'
    NOT = 'not'
  end

  class ConditionEvaluator
    DEFAULT_OPERATOR_TYPES = [
      ConditionalOperatorTypes::AND,
      ConditionalOperatorTypes::OR,
      ConditionalOperatorTypes::NOT
    ].freeze

    attr_reader :user_attributes

    def initialize(user_attributes)
      @user_attributes = user_attributes
    end

    def and_evaluator(conditions)
      # Evaluates an array of conditions as if the evaluator had been applied
      # to each entry and the results AND-ed together.
      #
      # conditions - Array of conditions ex: [operand_1, operand_2]
      #
      # Returns boolean true if all operands evaluate to true.

      conditions.each do |condition|
        result = evaluate(condition)
        return result if result == false
      end

      true
    end

    def or_evaluator(conditions)
      # Evaluates an array of conditions as if the evaluator had been applied
      # to each entry and the results AND-ed together.
      #
      # conditions - Array of conditions ex: [operand_1, operand_2]
      #
      # Returns boolean true if any operand evaluates to true.

      conditions.each do |condition|
        result = evaluate(condition)
        return result if result == true
      end

      false
    end

    def not_evaluator(single_condition)
      # Evaluates an array of conditions as if the evaluator had been applied
      # to a single entry and NOT was applied to the result.
      #
      # single_condition - Array of a single condition ex: [operand_1]
      #
      # Returns boolean true if the operand evaluates to false.

      return false if single_condition.length != 1

      !evaluate(single_condition[0])
    end

    def evaluator(condition_array)
      # Method to compare single audience condition against provided user data i.e. attributes.
      #
      # condition_array - Array consisting of condition key and corresponding value.
      #
      # Returns boolean indicating the result of comparing the condition value against the user attributes.

      condition_array[1] == @user_attributes[condition_array[0]]
    end

    def evaluate(conditions)
      # Top level method to evaluate audience conditions.
      #
      # conditions - Nested array of and/or conditions.
      #              Example: ['and', operand_1, ['or', operand_2, operand_3]]
      #
      # Returns boolean result of evaluating the conditions evaluated.

      if conditions.is_a? Array
        operator_type = conditions[0]
        return false unless DEFAULT_OPERATOR_TYPES.include?(operator_type)
        case operator_type
        when ConditionalOperatorTypes::AND
          return and_evaluator(conditions[1..-1])
        when ConditionalOperatorTypes::OR
          return or_evaluator(conditions[1..-1])
        when ConditionalOperatorTypes::NOT
          return not_evaluator(conditions[1..-1])
        end
      end

      # Create array of condition key and corresponding value of audience condition.
      condition_array = audience_condition_deserializer(conditions)

      # Compare audience condition against provided user data i.e. attributes.
      evaluator(condition_array)
    end

    private

    def audience_condition_deserializer(condition)
      # Deserializer defining how hashes need to be decoded for audience conditions.
      #
      # condition - Hash representing one audience condition.
      #
      # Returns array consisting of condition key and corresponding value.

      [condition['name'], condition['value']]
    end
  end
end
