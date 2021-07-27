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
module Optimizely
  module ConditionTreeEvaluator
    # Operator types
    AND_CONDITION = 'and'
    OR_CONDITION = 'or'
    NOT_CONDITION = 'not'

    EVALUATORS_BY_OPERATOR_TYPE = {
      AND_CONDITION => :and_evaluator,
      OR_CONDITION => :or_evaluator,
      NOT_CONDITION => :not_evaluator
    }.freeze

    OPERATORS = [AND_CONDITION, OR_CONDITION, NOT_CONDITION].freeze

    module_function

    def evaluate(conditions, leaf_evaluator)
      # Top level method to evaluate audience conditions.
      #
      # conditions - Nested array of and/or conditions.
      #              Example: ['and', operand_1, ['or', operand_2, operand_3]]
      #
      # leaf_evaluator - Function which will be called to evaluate leaf condition values.
      #
      # Returns boolean if the given user attributes match/don't match the given conditions,
      #         nil if the given conditions are invalid or can't be evaluated.

      if conditions.is_a? Array
        first_operator =  conditions[0]
        rest_of_conditions = conditions[1..-1]

        # Operator to apply is not explicit - assume 'or'
        unless EVALUATORS_BY_OPERATOR_TYPE.include?(conditions[0])
          first_operator = OR_CONDITION
          rest_of_conditions = conditions
        end

        return send(EVALUATORS_BY_OPERATOR_TYPE[first_operator], rest_of_conditions, leaf_evaluator)
      end

      leaf_evaluator.call(conditions)
    end

    def and_evaluator(conditions, leaf_evaluator)
      # Evaluates an array of conditions as if the evaluator had been applied
      # to each entry and the results AND-ed together.
      #
      # conditions - Array of conditions ex: [operand_1, operand_2]
      #
      # leaf_evaluator - Function which will be called to evaluate leaf condition values.
      #
      # Returns boolean if the user attributes match/don't match the given conditions,
      #         nil if the user attributes and conditions can't be evaluated.

      found_nil = false
      conditions.each do |condition|
        result = evaluate(condition, leaf_evaluator)
        return result if result == false

        found_nil = true if result.nil?
      end

      found_nil ? nil : true
    end

    def not_evaluator(single_condition, leaf_evaluator)
      # Evaluates an array of conditions as if the evaluator had been applied
      # to a single entry and NOT was applied to the result.
      #
      # single_condition - Array of a single condition ex: [operand_1]
      #
      # leaf_evaluator - Function which will be called to evaluate leaf condition values.
      #
      # Returns boolean if the user attributes match/don't match the given conditions,
      #         nil if the user attributes and conditions can't be evaluated.

      return nil if single_condition.empty?

      result = evaluate(single_condition[0], leaf_evaluator)
      result.nil? ? nil : !result
    end

    def or_evaluator(conditions, leaf_evaluator)
      # Evaluates an array of conditions as if the evaluator had been applied
      # to each entry and the results OR-ed together.
      #
      # conditions - Array of conditions ex: [operand_1, operand_2]
      #
      # leaf_evaluator - Function which will be called to evaluate leaf condition values.
      #
      # Returns boolean if the user attributes match/don't match the given conditions,
      #         nil if the user attributes and conditions can't be evaluated.

      found_nil = false
      conditions.each do |condition|
        result = evaluate(condition, leaf_evaluator)
        return result if result == true

        found_nil = true if result.nil?
      end

      found_nil ? nil : false
    end
  end
end
