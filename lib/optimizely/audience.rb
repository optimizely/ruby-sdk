# frozen_string_literal: true

#
#    Copyright 2016-2017, 2019, Optimizely and contributors
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

module Optimizely
  module Audience
    module_function

    def user_in_experiment?(config, experiment, attributes)
      # Determine for given experiment if user satisfies the audiences for the experiment.
      #
      # config - Representation of the Optimizely project config.
      # experiment - Experiment for which visitor is to be bucketed.
      # attributes - Hash representing user attributes which will be used in determining if
      #              the audience conditions are met.
      #
      # Returns boolean representing if user satisfies audience conditions for the audiences or not.

      audience_conditions = experiment['audienceConditions'] || experiment['audienceIds']

      # Return true if there are no audiences
      return true if audience_conditions.empty?

      attributes ||= {}

      custom_attr_condition_evaluator = CustomAttributeConditionEvaluator.new(attributes)

      evaluate_custom_attr = lambda do |condition|
        return custom_attr_condition_evaluator.evaluate(condition)
      end

      evaluate_audience = lambda do |audience_id|
        audience = config.get_audience_from_id(audience_id)
        return nil unless audience

        audience_conditions = audience['conditions']
        audience_conditions = JSON.parse(audience_conditions) if audience_conditions.is_a?(String)
        return ConditionTreeEvaluator.evaluate(audience_conditions, evaluate_custom_attr)
      end

      return true if ConditionTreeEvaluator.evaluate(audience_conditions, evaluate_audience)

      false
    end
  end
end
