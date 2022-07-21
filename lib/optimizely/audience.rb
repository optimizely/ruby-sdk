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
require 'json'
require_relative './custom_attribute_condition_evaluator'
require_relative 'condition_tree_evaluator'
require_relative 'helpers/constants'

module Optimizely
  module Audience
    module_function

    def user_meets_audience_conditions?(config, experiment, user_context, logger, logging_hash = nil, logging_key = nil)
      # Determine for given experiment/rollout rule if user satisfies the audience conditions.
      #
      # config - Representation of the Optimizely project config.
      # experiment - Experiment/Rollout rule in which user is to be bucketed.
      # user_context - Optimizely user context instance
      # logger - Provides a logger instance.
      # logging_hash - Optional string representing logs hash inside Helpers::Constants.
      #                This defaults to 'EXPERIMENT_AUDIENCE_EVALUATION_LOGS'.
      # logging_key - Optional string to be logged as an identifier of experiment under evaluation.
      #               This defaults to experiment['key'].
      #
      # Returns boolean representing if user satisfies audience conditions for the audiences or not.
      decide_reasons = []
      logging_hash ||= 'EXPERIMENT_AUDIENCE_EVALUATION_LOGS'
      logging_key ||= experiment['key']

      logs_hash = Object.const_get "Optimizely::Helpers::Constants::#{logging_hash}"

      audience_conditions = experiment['audienceConditions'] || experiment['audienceIds']

      message = format(logs_hash['EVALUATING_AUDIENCES_COMBINED'], logging_key, audience_conditions)
      logger.log(Logger::DEBUG, message)

      # Return true if there are no audiences
      if audience_conditions.empty?
        message = format(logs_hash['AUDIENCE_EVALUATION_RESULT_COMBINED'], logging_key, 'TRUE')
        logger.log(Logger::INFO, message)
        decide_reasons.push(message)
        return true, decide_reasons
      end

      custom_attr_condition_evaluator = CustomAttributeConditionEvaluator.new(user_context, logger)

      evaluate_custom_attr = lambda do |condition|
        return custom_attr_condition_evaluator.evaluate(condition)
      end

      evaluate_audience = lambda do |audience_id|
        audience = config.get_audience_from_id(audience_id)
        return nil unless audience

        audience_conditions = audience['conditions']
        message = format(logs_hash['EVALUATING_AUDIENCE'], audience_id, audience_conditions)
        logger.log(Logger::DEBUG, message)
        decide_reasons.push(message)

        audience_conditions = JSON.parse(audience_conditions) if audience_conditions.is_a?(String)
        result = ConditionTreeEvaluator.evaluate(audience_conditions, evaluate_custom_attr)
        result_str = result.nil? ? 'UNKNOWN' : result.to_s.upcase
        message = format(logs_hash['AUDIENCE_EVALUATION_RESULT'], audience_id, result_str)
        logger.log(Logger::DEBUG, message)
        decide_reasons.push(message)

        result
      end

      eval_result = ConditionTreeEvaluator.evaluate(audience_conditions, evaluate_audience)
      eval_result ||= false

      message = format(logs_hash['AUDIENCE_EVALUATION_RESULT_COMBINED'], logging_key, eval_result.to_s.upcase)
      logger.log(Logger::INFO, message)
      decide_reasons.push(message)

      [eval_result, decide_reasons]
    end

    def get_segments(conditions)
      # Return any audience segments from provided conditions.
      #
      # conditions - Nested array of and/or conditions.
      #              Example: ['and', operand_1, ['or', operand_2, operand_3]]
      #
      # Returns unique array of segment names.
      conditions = JSON.parse(conditions) if conditions.is_a?(String)
      @parse_segments.call(conditions).uniq
    end

    @parse_segments = lambda { |conditions|
      # Return any audience segments from provided conditions.
      # Helper function for get_segments.
      #
      # conditions - Nested array of and/or conditions.
      #              Example: ['and', operand_1, ['or', operand_2, operand_3]]
      #
      # Returns array of segment names.
      segments = []

      conditions.each do |condition|
        case condition
        when Array
          segments.concat @parse_segments.call(condition)
        when Hash
          segments.push(condition['value']) if condition.fetch('match', nil) == 'qualified'
        end
      end

      segments
    }
  end
end
