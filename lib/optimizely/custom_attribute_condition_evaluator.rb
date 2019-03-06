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
require_relative 'helpers/constants'
require_relative 'helpers/validator'

module Optimizely
  class CustomAttributeConditionEvaluator
    CUSTOM_ATTRIBUTE_CONDITION_TYPE = 'custom_attribute'

    # Conditional match types
    EXACT_MATCH_TYPE = 'exact'
    EXISTS_MATCH_TYPE = 'exists'
    GREATER_THAN_MATCH_TYPE = 'gt'
    LESS_THAN_MATCH_TYPE = 'lt'
    SUBSTRING_MATCH_TYPE = 'substring'

    EVALUATORS_BY_MATCH_TYPE = {
      EXACT_MATCH_TYPE => :exact_evaluator,
      EXISTS_MATCH_TYPE => :exists_evaluator,
      GREATER_THAN_MATCH_TYPE => :greater_than_evaluator,
      LESS_THAN_MATCH_TYPE => :less_than_evaluator,
      SUBSTRING_MATCH_TYPE => :substring_evaluator
    }.freeze

    attr_reader :user_attributes

    def initialize(user_attributes, logger)
      @user_attributes = user_attributes
      @logger = logger
    end

    def evaluate(leaf_condition)
      # Top level method to evaluate audience conditions.
      #
      # conditions - Nested array of and/or conditions.
      #              Example: ['and', operand_1, ['or', operand_2, operand_3]]
      #
      # Returns boolean if the given user attributes match/don't match the given conditions,
      #         nil if the given conditions can't be evaluated.

      unless leaf_condition['type'] == CUSTOM_ATTRIBUTE_CONDITION_TYPE
        @logger.log(
          Logger::WARN,
          format(Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNKNOWN_CONDITION_TYPE'], leaf_condition)
        )
        return nil
      end

      condition_match = leaf_condition['match'] || EXACT_MATCH_TYPE

      if !@user_attributes.key?(leaf_condition['name']) && condition_match != EXISTS_MATCH_TYPE
        @logger.log(
          Logger::DEBUG,
          format(
            Helpers::Constants::AUDIENCE_EVALUATION_LOGS['MISSING_ATTRIBUTE_VALUE'],
            leaf_condition,
            leaf_condition['name']
          )
        )
        return nil
      end

      if @user_attributes[leaf_condition['name']].nil? && condition_match != EXISTS_MATCH_TYPE
        @logger.log(
          Logger::DEBUG,
          format(
            Helpers::Constants::AUDIENCE_EVALUATION_LOGS['NULL_ATTRIBUTE_VALUE'],
            leaf_condition,
            leaf_condition['name']
          )
        )
        return nil
      end

      unless EVALUATORS_BY_MATCH_TYPE.include?(condition_match)
        @logger.log(
          Logger::WARN,
          format(Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNKNOWN_MATCH_TYPE'], leaf_condition)
        )
        return nil
      end

      send(EVALUATORS_BY_MATCH_TYPE[condition_match], leaf_condition)
    end

    def exact_evaluator(condition)
      # Evaluate the given exact match condition for the given user attributes.
      #
      # Returns boolean true if numbers values matched, i.e 2 is equal to 2.0
      #                 true if the user attribute value is equal (===) to the condition value,
      #                 false if the user attribute value is not equal (!==) to the condition value,
      #                 nil if the condition value or user attribute value has an invalid type,
      #                 or if there is a mismatch between the user attribute type and the condition value type.

      condition_value = condition['value']

      user_provided_value = @user_attributes[condition['name']]

      if !value_type_valid_for_exact_conditions?(condition_value) ||
         (condition_value.is_a?(Numeric) && !Helpers::Validator.finite_number?(condition_value))
        @logger.log(
          Logger::WARN,
          format(Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNKNOWN_CONDITION_VALUE'], condition)
        )
        return nil
      end

      if !value_type_valid_for_exact_conditions?(user_provided_value) ||
         !Helpers::Validator.same_types?(condition_value, user_provided_value)
        @logger.log(
          Logger::WARN,
          format(
            Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNEXPECTED_TYPE'],
            condition,
            user_provided_value.class,
            condition['name']
          )
        )
        return nil
      end

      if user_provided_value.is_a?(Numeric) && !Helpers::Validator.finite_number?(user_provided_value)
        @logger.log(
          Logger::WARN,
          format(
            Helpers::Constants::AUDIENCE_EVALUATION_LOGS['INFINITE_ATTRIBUTE_VALUE'],
            condition,
            condition['name']
          )
        )
        return nil
      end

      condition_value == user_provided_value
    end

    def exists_evaluator(condition)
      # Evaluate the given exists match condition for the given user attributes.
      # Returns boolean true if both:
      #                    1) the user attributes have a value for the given condition, and
      #                    2) the user attribute value is neither nil nor undefined
      #                 Returns false otherwise

      !@user_attributes[condition['name']].nil?
    end

    def greater_than_evaluator(condition)
      # Evaluate the given greater than match condition for the given user attributes.
      # Returns boolean true if the user attribute value is greater than the condition value,
      #                 false if the user attribute value is less than or equal to the condition value,
      #                 nil if the condition value isn't a number or the user attribute value isn't a number.

      condition_value = condition['value']
      user_provided_value = @user_attributes[condition['name']]

      return nil unless valid_numeric_values?(user_provided_value, condition_value, condition)

      user_provided_value > condition_value
    end

    def less_than_evaluator(condition)
      # Evaluate the given less than match condition for the given user attributes.
      # Returns boolean true if the user attribute value is less than the condition value,
      #                 false if the user attribute value is greater than or equal to the condition value,
      #                 nil if the condition value isn't a number or the user attribute value isn't a number.

      condition_value = condition['value']
      user_provided_value = @user_attributes[condition['name']]

      return nil unless valid_numeric_values?(user_provided_value, condition_value, condition)

      user_provided_value < condition_value
    end

    def substring_evaluator(condition)
      # Evaluate the given substring match condition for the given user attributes.
      # Returns boolean true if the condition value is a substring of the user attribute value,
      #                 false if the condition value is not a substring of the user attribute value,
      #                 nil if the condition value isn't a string or the user attribute value isn't a string.

      condition_value = condition['value']
      user_provided_value = @user_attributes[condition['name']]

      unless condition_value.is_a?(String)
        @logger.log(
          Logger::WARN,
          format(Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNKNOWN_CONDITION_VALUE'], condition)
        )
        return nil
      end

      unless user_provided_value.is_a?(String)
        @logger.log(
          Logger::WARN,
          format(
            Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNEXPECTED_TYPE'],
            condition,
            user_provided_value.class,
            condition['name']
          )
        )
        return nil
      end

      user_provided_value.include? condition_value
    end

    private

    def valid_numeric_values?(user_value, condition_value, condition)
      # Returns true if user and condition values are valid numeric.
      #         false otherwise.

      unless Helpers::Validator.finite_number?(condition_value)
        @logger.log(
          Logger::WARN,
          format(Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNKNOWN_CONDITION_VALUE'], condition)
        )
        return false
      end

      unless user_value.is_a?(Numeric)
        @logger.log(
          Logger::WARN,
          format(
            Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNEXPECTED_TYPE'],
            condition,
            user_value.class,
            condition['name']
          )
        )
        return false
      end

      unless Helpers::Validator.finite_number?(user_value)
        @logger.log(
          Logger::WARN,
          format(
            Helpers::Constants::AUDIENCE_EVALUATION_LOGS['INFINITE_ATTRIBUTE_VALUE'],
            condition,
            condition['name']
          )
        )
        return false
      end

      true
    end

    def value_type_valid_for_exact_conditions?(value)
      # Returns true if the value is valid for exact conditions. Valid values include
      #  strings or booleans or is a number.
      #  false otherwise.

      (Helpers::Validator.boolean? value) || (value.is_a? String) || value.is_a?(Numeric)
    end
  end
end
