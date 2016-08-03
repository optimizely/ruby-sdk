require 'json'
require_relative './condition'

module Optimizely
  module Audience
    module_function

    def user_in_experiment?(config, experiment_key, attributes)
      # Determine for given experiment if user satisfies the audiences for the experiment.
      #
      # config - Representation of the Optimizely project config.
      # experiment_key - Key representing experiment for which visitor is to be bucketed.
      # attributes - Hash representing user attributes which will be used in determining if
      #              the audience conditions are met.
      #
      # Returns boolean representing if user satisfies audience conditions for any of the audiences or not.

      audience_ids = config.get_audience_ids_for_experiment(experiment_key)

      # Return true if there are no audiences
      return true if audience_ids.empty?

      # Return false if there are audiences but no attributes
      return false unless attributes

      # Return true if any one of the audience conditions are met
      @condition_evaluator = ConditionEvaluator.new(attributes)
      audience_ids.each do |audience_id|
        audience_conditions = config.get_audience_conditions_from_id(audience_id)
        audience_conditions = JSON.load(audience_conditions)
        return true if @condition_evaluator.evaluate(audience_conditions)
      end

      false
    end
  end
end
