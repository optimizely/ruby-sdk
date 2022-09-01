# frozen_string_literal: true

#
#    Copyright 2019-2020, 2022, Optimizely and contributors
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
require_relative 'exceptions'
require_relative 'helpers/constants'
require_relative 'helpers/validator'
require_relative 'semantic_version'

module Optimizely
  class UserConditionEvaluator
    CONDITION_TYPES = %w[custom_attribute third_party_dimension].freeze

    # Conditional match types
    EXACT_MATCH_TYPE = 'exact'
    EXISTS_MATCH_TYPE = 'exists'
    GREATER_THAN_MATCH_TYPE = 'gt'
    GREATER_EQUAL_MATCH_TYPE = 'ge'
    LESS_THAN_MATCH_TYPE = 'lt'
    LESS_EQUAL_MATCH_TYPE = 'le'
    SUBSTRING_MATCH_TYPE = 'substring'
    SEMVER_EQ = 'semver_eq'
    SEMVER_GE = 'semver_ge'
    SEMVER_GT = 'semver_gt'
    SEMVER_LE = 'semver_le'
    SEMVER_LT = 'semver_lt'
    QUALIFIED_MATCH_TYPE = 'qualified'

    EVALUATORS_BY_MATCH_TYPE = {
      EXACT_MATCH_TYPE => :exact_evaluator,
      EXISTS_MATCH_TYPE => :exists_evaluator,
      GREATER_THAN_MATCH_TYPE => :greater_than_evaluator,
      GREATER_EQUAL_MATCH_TYPE => :greater_than_or_equal_evaluator,
      LESS_THAN_MATCH_TYPE => :less_than_evaluator,
      LESS_EQUAL_MATCH_TYPE => :less_than_or_equal_evaluator,
      SUBSTRING_MATCH_TYPE => :substring_evaluator,
      SEMVER_EQ => :semver_equal_evaluator,
      SEMVER_GE => :semver_greater_than_or_equal_evaluator,
      SEMVER_GT => :semver_greater_than_evaluator,
      SEMVER_LE => :semver_less_than_or_equal_evaluator,
      SEMVER_LT => :semver_less_than_evaluator,
      QUALIFIED_MATCH_TYPE => :qualified_evaluator
    }.freeze

    attr_reader :user_attributes

    def initialize(user_context, logger)
      @user_context = user_context
      @user_attributes = user_context.user_attributes
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

      unless CONDITION_TYPES.include? leaf_condition['type']
        @logger.log(
          Logger::WARN,
          format(Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNKNOWN_CONDITION_TYPE'], leaf_condition)
        )
        return nil
      end

      condition_match = leaf_condition['match'] || EXACT_MATCH_TYPE

      if !@user_attributes.key?(leaf_condition['name']) && ![EXISTS_MATCH_TYPE, QUALIFIED_MATCH_TYPE].include?(condition_match)
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

      if @user_attributes[leaf_condition['name']].nil? && ![EXISTS_MATCH_TYPE, QUALIFIED_MATCH_TYPE].include?(condition_match)
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

      begin
        send(EVALUATORS_BY_MATCH_TYPE[condition_match], leaf_condition)
      rescue InvalidAttributeType
        condition_name = leaf_condition['name']
        user_value = @user_attributes[condition_name]

        @logger.log(
          Logger::WARN,
          format(
            Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNEXPECTED_TYPE'],
            leaf_condition,
            user_value.class,
            condition_name
          )
        )
        nil
      rescue InvalidSemanticVersion
        condition_name = leaf_condition['name']

        @logger.log(
          Logger::WARN,
          format(
            Helpers::Constants::AUDIENCE_EVALUATION_LOGS['INVALID_SEMANTIC_VERSION'],
            leaf_condition,
            condition_name
          )
        )
        nil
      end
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
        raise InvalidAttributeType
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

    def greater_than_or_equal_evaluator(condition)
      # Evaluate the given greater than or equal match condition for the given user attributes.
      # Returns boolean true if the user attribute value is greater than or equal to the condition value,
      #                 false if the user attribute value is less than the condition value,
      #                 nil if the condition value isn't a number or the user attribute value isn't a number.

      condition_value = condition['value']
      user_provided_value = @user_attributes[condition['name']]

      return nil unless valid_numeric_values?(user_provided_value, condition_value, condition)

      user_provided_value >= condition_value
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

    def less_than_or_equal_evaluator(condition)
      # Evaluate the given less than or equal match condition for the given user attributes.
      # Returns boolean true if the user attribute value is less than or equal to the condition value,
      #                 false if the user attribute value is greater than the condition value,
      #                 nil if the condition value isn't a number or the user attribute value isn't a number.

      condition_value = condition['value']
      user_provided_value = @user_attributes[condition['name']]

      return nil unless valid_numeric_values?(user_provided_value, condition_value, condition)

      user_provided_value <= condition_value
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

      raise InvalidAttributeType unless user_provided_value.is_a?(String)

      user_provided_value.include? condition_value
    end

    def semver_equal_evaluator(condition)
      # Evaluate the given semantic version equal match target version for the user version.
      # Returns boolean true if the user version is equal to the target version,
      #                 false if the user version is not equal to the target version

      target_version = condition['value']
      user_version = @user_attributes[condition['name']]

      SemanticVersion.compare_user_version_with_target_version(target_version, user_version).zero?
    end

    def semver_greater_than_evaluator(condition)
      # Evaluate the given semantic version greater than match target version for the user version.
      # Returns boolean true if the user version is greater than the target version,
      #                 false if the user version is less than or equal to the target version

      target_version = condition['value']
      user_version = @user_attributes[condition['name']]

      SemanticVersion.compare_user_version_with_target_version(target_version, user_version).positive?
    end

    def semver_greater_than_or_equal_evaluator(condition)
      # Evaluate the given semantic version greater than or equal to match target version for the user version.
      # Returns boolean true if the user version is greater than or equal to the target version,
      #                 false if the user version is less than the target version

      target_version = condition['value']
      user_version = @user_attributes[condition['name']]

      SemanticVersion.compare_user_version_with_target_version(target_version, user_version) >= 0
    end

    def semver_less_than_evaluator(condition)
      # Evaluate the given semantic version less than match target version for the user version.
      # Returns boolean true if the user version is less than the target version,
      #                 false if the user version is greater than or equal to the target version

      target_version = condition['value']
      user_version = @user_attributes[condition['name']]

      SemanticVersion.compare_user_version_with_target_version(target_version, user_version).negative?
    end

    def semver_less_than_or_equal_evaluator(condition)
      # Evaluate the given semantic version less than or equal to match target version for the user version.
      # Returns boolean true if the user version is less than or equal to the target version,
      #                 false if the user version is greater than the target version

      target_version = condition['value']
      user_version = @user_attributes[condition['name']]

      SemanticVersion.compare_user_version_with_target_version(target_version, user_version) <= 0
    end

    def qualified_evaluator(condition)
      # Evaluate the given match condition for the given user qaulified segments.
      # Returns boolean true if condition value is in the user's qualified segments,
      #                 false if the condition value is not in the user's qualified segments,
      #                 nil if the condition value isn't a string.

      condition_value = condition['value']

      unless condition_value.is_a?(String)
        @logger.log(
          Logger::WARN,
          format(Helpers::Constants::AUDIENCE_EVALUATION_LOGS['UNKNOWN_CONDITION_VALUE'], condition)
        )
        return nil
      end

      @user_context.qualified_for?(condition_value)
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

      raise InvalidAttributeType unless user_value.is_a?(Numeric)

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
