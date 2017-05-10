#
#    Copyright 2017, Optimizely and contributors
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
  class DecisionService
  
    attr_reader :bucketer
    attr_reader :config

    def initialize(config)
      @config = config
      @bucketer = Bucketer.new(@config)
    end

    def get_variation(experiment_key, user_id, attributes)
      # Check to make sure experiment is active
      # remember to come back and make sure this covers launched
      unless @config.experiment_running?(experiment_key)
        @config.logger.log(Logger::INFO, "Experiment '#{experiment_key}' is not running.")
        return nil
      end

      # Check if user is in a forced variation
      variation_id = get_forced_variation_id(experiment_key, user_id)

      if variation_id.nil?
        unless Audience.user_in_experiment?(@config, experiment_key, attributes)
          @config.logger.log(Logger::INFO,
                      "User '#{user_id}' does not meet the conditions to be in experiment '#{experiment_key}'.")
          return nil
        end

        variation_id = @bucketer.bucket(experiment_key, user_id)
      end

      variation_id
    end

    # consider making this private and testing implicitly
    def get_forced_variation_id(experiment_key, user_id)
      # Determine if a user is forced into a variation for the given experiment and return the ID of that variation.
      #
      # experiment_key - Key representing the experiment for which user is to be bucketed.
      # user_id - ID for the user.
      #
      # Returns variation ID into which user_id is forced (nil if no variation).

      forced_variations = @config.get_forced_variations(experiment_key)

      return nil unless forced_variations

      forced_variation_key = forced_variations[user_id]

      return nil unless forced_variation_key

      forced_variation_id = @config.get_variation_id_from_key(experiment_key, forced_variation_key)

      unless forced_variation_id
        @config.logger.log(
          Logger::INFO,
          "Variation key '#{forced_variation_key}' is not in datafile. Not activating user '#{user_id}'."
        )
        return nil
      end

      @config.logger.log(Logger::INFO, "User '#{user_id}' is forced in variation '#{forced_variation_key}'.")
      forced_variation_id
    end
  end
end
