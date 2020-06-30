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

    def user_meets_audience_conditions?(config, experiment, attributes, logger)
      # Determine for given experiment if user satisfies the audiences for the experiment.
      #
      # config - Representation of the Optimizely project config.
      # experiment - Experiment for which visitor is to be bucketed.
      # attributes - Hash representing user attributes which will be used in determining if
      #              the audience conditions are met.
      #
      # Returns boolean representing if user satisfies audience conditions for the audiences or not.

      audience_conditions = experiment['audienceConditions'] || experiment['audienceIds']

      eval_audience_combined_log = Helpers::Constants::AUDIENCE_EVALUATION_LOGS['EVALUATING_EXPERIMENT_COMBINED']
      audience_result_combined_log = Helpers::Constants::AUDIENCE_EVALUATION_LOGS['EXPERIMENT_RESULT_COMBINED']

      logger.log(
        Logger::DEBUG,
        format(
          eval_audience_combined_log,
          experiment['key'],
          audience_conditions
        )
      )

      # Return true if there are no audiences
      if audience_conditions.empty?
        logger.log(
          Logger::INFO,
          format(
            audience_result_combined_log,
            experiment['key'],
            'TRUE'
          )
        )
        return true
      end

      attributes ||= {}

      custom_attr_condition_evaluator = CustomAttributeConditionEvaluator.new(attributes, logger)

      evaluate_custom_attr = lambda do |condition|
        return custom_attr_condition_evaluator.evaluate(condition)
      end

      evaluate_audience = lambda do |audience_id|
        audience = config.get_audience_from_id(audience_id)
        return nil unless audience

        audience_conditions = audience['conditions']
        logger.log(
          Logger::DEBUG,
          format(
            Helpers::Constants::AUDIENCE_EVALUATION_LOGS['EVALUATING_AUDIENCE'],
            audience_id,
            audience_conditions
          )
        )

        audience_conditions = JSON.parse(audience_conditions) if audience_conditions.is_a?(String)
        result = ConditionTreeEvaluator.evaluate(audience_conditions, evaluate_custom_attr)
        result_str = result.nil? ? 'UNKNOWN' : result.to_s.upcase
        logger.log(
          Logger::DEBUG,
          format(Helpers::Constants::AUDIENCE_EVALUATION_LOGS['AUDIENCE_EVALUATION_RESULT'], audience_id, result_str)
        )
        result
      end

      eval_result = ConditionTreeEvaluator.evaluate(audience_conditions, evaluate_audience)

      eval_result ||= false

      logger.log(
        Logger::INFO,
        format(
          audience_result_combined_log,
          experiment['key'],
          eval_result.to_s.upcase
        )
      )

      eval_result
    end
  end
end
