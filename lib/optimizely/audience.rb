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
require_relative './condition'

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
      # Returns boolean representing if user satisfies audience conditions for any of the audiences or not.

      audience_ids = experiment['audienceIds']

      # Return true if there are no audiences
      return true if audience_ids.empty?

      # Return false if there are audiences but no attributes
      return false unless attributes

      # Return true if any one of the audience conditions are met
      @condition_evaluator = ConditionEvaluator.new(attributes)
      audience_ids.each do |audience_id|
        audience = config.get_audience_from_id(audience_id)
        audience_conditions = audience['conditions']
        audience_conditions = JSON.parse(audience_conditions)
        return true if @condition_evaluator.evaluate(audience_conditions)
      end

      false
    end
  end
end
