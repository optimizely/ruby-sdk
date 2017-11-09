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
require_relative './bucketer'

module Optimizely

  RESERVED_ATTRIBUTE_KEY_BUCKETING_ID = "\$opt_bucketing_id".freeze

  class DecisionService
    # Optimizely's decision service that determines into which variation of an experiment a user will be allocated.
    #
    # The decision service contains all logic relating to how a user bucketing decisions is made.
    # This includes all of the following (in order):
    #
    # 1. Check experiment status
    # 2. Check forced bucketing
    # 3. Check whitelisting
    # 4. Check user profile service for past bucketing decisions (sticky bucketing)
    # 5. Check audience targeting
    # 6. Use Murmurhash3 to bucket the user

    attr_reader :bucketer
    attr_reader :config

    def initialize(config, user_profile_service = nil)
      @config = config
      @user_profile_service = user_profile_service
      @bucketer = Bucketer.new(@config)
    end

    def get_variation(experiment_key, user_id, attributes = nil)
      # Determines variation into which user will be bucketed.
      #
      # experiment_key - Experiment for which visitor variation needs to be determined
      # user_id - String ID for user
      # attributes - Hash representing user attributes
      #
      # Returns variation ID where visitor will be bucketed (nil if experiment is inactive or user does not meet audience conditions)

      # By default, the bucketing ID should be the user ID
      bucketing_id = get_bucketing_id(user_id, attributes)
      # Check to make sure experiment is active
      experiment = @config.get_experiment_from_key(experiment_key)
      if experiment.nil?
        return nil
      end

      experiment_id = experiment['id']
      unless @config.experiment_running?(experiment)
        @config.logger.log(Logger::INFO, "Experiment '#{experiment_key}' is not running.")
        return nil
      end

      # Check if a forced variation is set for the user
      forced_variation = @config.get_forced_variation(experiment_key, user_id)
      return forced_variation['id'] if forced_variation

      # Check if user is in a white-listed variation
      whitelisted_variation_id = get_whitelisted_variation_id(experiment_key, user_id)
      return whitelisted_variation_id if whitelisted_variation_id

      # Check for saved bucketing decisions
      user_profile = get_user_profile(user_id)
      saved_variation_id = get_saved_variation_id(experiment_id, user_profile)
      if saved_variation_id
        @config.logger.log(
          Logger::INFO,
          "Returning previously activated variation ID #{saved_variation_id} of experiment '#{experiment_key}' for user '#{user_id}' from user profile."
        )
        return saved_variation_id
      end

      # Check audience conditions
      unless Audience.user_in_experiment?(@config, experiment, attributes)
        @config.logger.log(
          Logger::INFO,
          "User '#{user_id}' does not meet the conditions to be in experiment '#{experiment_key}'."
        )
        return nil
      end

      # Bucket normally
      variation = @bucketer.bucket(experiment, bucketing_id, user_id)
      variation_id = variation ? variation['id'] : nil

      # Persist bucketing decision
      save_user_profile(user_profile, experiment_id, variation_id)
      variation_id
    end

    def get_variation_for_feature(feature_flag, user_id, attributes = nil)
      # Get the variation the user is bucketed into for the given FeatureFlag.
      #
      # feature_flag - The feature flag the user wants to access
      # user_id - String ID for the user
      # attributes - Hash representing user attributes
      #
      # Returns hash with the experiment and variation where visitor will be bucketed (nil if the user is not bucketed into any of the experiments on the feature)

      # check if the feature is being experiment on and whether the user is bucketed into the experiment
      decision = get_variation_for_feature_experiment(feature_flag, user_id, attributes)
      return decision unless decision.nil?

      feature_flag_key = feature_flag['key']
      variation = get_variation_for_feature_rollout(feature_flag, user_id, attributes)
      if variation
        @config.logger.log(
          Logger::INFO,
          "User '#{user_id}' is bucketed into a rollout for feature flag '#{feature_flag_key}'."
        )
        # return decision with nil experiment so we don't track impressions for it
        return {
          'experiment' => nil,
          'variation' => variation
        }
      else
        @config.logger.log(
          Logger::INFO,
          "User '#{user_id}' is not bucketed into a rollout for feature flag '#{feature_flag_key}'."
        )
      end

      nil
    end

    def get_variation_for_feature_experiment(feature_flag, user_id, attributes = nil)
      # Gets the variation the user is bucketed into for the feature flag's experiment.
      #
      # feature_flag - The feature flag the user wants to access
      # user_id - String ID for the user
      # attributes - Hash representing user attributes
      #
      # Returns a hash with the experiment and variation where visitor will be bucketed
      # or nil if the user is not bucketed into any of the experiments on the feature
      feature_flag_key = feature_flag['key']
      if feature_flag['experimentIds'].empty?
        @config.logger.log(
          Logger::DEBUG,
          "The feature flag '#{feature_flag_key}' is not used in any experiments."
        )
        return nil
      else
        # Evaluate each experiment and return the first bucketed experiment variation
        feature_flag['experimentIds'].each do |experiment_id|
          experiment = @config.experiment_id_map[experiment_id]
          unless experiment
            @config.logger.log(
              Logger::DEBUG,
              "Feature flag experiment with ID '#{experiment_id}' is not in the datafile."
            )
            return nil
          end
          experiment_key = experiment['key']
          variation_id = get_variation(experiment_key, user_id, attributes)
          next unless variation_id
          variation = @config.variation_id_map[experiment_key][variation_id]
          @config.logger.log(Logger::INFO,
                             "The user '#{user_id}' is bucketed into experiment '#{experiment_key}' of feature "\
                             "'#{feature_flag_key}'.")
          return {
            'experiment' => experiment,
            'variation' => variation
          }
        end
        @config.logger.log(
          Logger::INFO,
          "The user '#{user_id}' is not bucketed into any of the experiments on the feature '#{feature_flag_key}'."
        )
      end

      nil
    end

    def get_variation_for_feature_rollout(feature_flag, user_id, attributes = nil)
      # Determine which variation the user is in for a given rollout.
      # Returns the variation of the first experiment the user qualifies for.
      #
      # feature_flag - The feature flag the user wants to access
      # user_id - String ID for the user
      # attributes - Hash representing user attributes
      #
      # Returns the variation the user is bucketed into or nil if not bucketed into any of the targeting rules

      bucketing_id = get_bucketing_id(user_id, attributes)

      rollout_id = feature_flag['rolloutId']
      if rollout_id.nil? || rollout_id.empty?
        feature_flag_key = feature_flag['key']
        @config.logger.log(
          Logger::DEBUG,
          "Feature flag '#{feature_flag_key}' is not used in a rollout."
        )
        return nil
      end

      rollout = @config.get_rollout_from_id(rollout_id)
      if rollout.nil?
        @config.logger.log(
          Logger::DEBUG,
          "Rollout with ID '#{rollout_id}' is not in the datafile '#{feature_flag['key']}'"
        )
        return nil
      end

      return nil if rollout['experiments'].empty?

      rollout_rules = rollout['experiments']
      number_of_rules = rollout_rules.length - 1

      # Go through each experiment in order and try to get the variation for the user
      number_of_rules.times do |index|
        rollout_rule = rollout_rules[index]
        audience_id = rollout_rule['audienceIds'][0]
        audience = @config.get_audience_from_id(audience_id)
        audience_name = audience['name']

        # Check that user meets audience conditions for targeting rule
        unless Audience.user_in_experiment?(@config, rollout_rule, attributes)
          @config.logger.log(
            Logger::DEBUG,
            "User '#{user_id}' does not meet the conditions to be in rollout rule for audience '#{audience_name}'."
          )
          # move onto the next targeting rule
          next
        end

        @config.logger.log(
          Logger::DEBUG,
          "Attempting to bucket user '#{user_id}' into rollout rule for audience '#{audience_name}'."
        )
        # Evaluate if user satisfies the traffic allocation for this rollout rule
        variation = @bucketer.bucket(rollout_rule, bucketing_id, user_id)
        return variation unless variation.nil?

        # User failed traffic allocation, jump to Everyone Else rule
        @config.logger.log(
          Logger::DEBUG,
          "User '#{user_id}' was excluded due to traffic allocation. Checking 'Everyone Else' rule now."
        )
        break
      end

      # get last rule which is the everyone else rule
      everyone_else_experiment = rollout_rules[number_of_rules]
      variation = @bucketer.bucket(everyone_else_experiment, bucketing_id ,user_id)
      if variation.nil?
        @config.logger.log(
          Logger::DEBUG,
          "User '#{user_id}' was excluded from the 'Everyone Else' rule for feature flag"
        )
        return nil
      else
        return variation
      end
    end

    private

    def get_whitelisted_variation_id(experiment_key, user_id)
      # Determine if a user is whitelisted into a variation for the given experiment and return the ID of that variation
      #
      # experiment_key - Key representing the experiment for which user is to be bucketed
      # user_id - ID for the user
      #
      # Returns variation ID into which user_id is whitelisted (nil if no variation)

      whitelisted_variations = @config.get_whitelisted_variations(experiment_key)

      return nil unless whitelisted_variations

      whitelisted_variation_key = whitelisted_variations[user_id]

      return nil unless whitelisted_variation_key

      whitelisted_variation_id = @config.get_variation_id_from_key(experiment_key, whitelisted_variation_key)

      unless whitelisted_variation_id
        @config.logger.log(
          Logger::INFO,
          "User '#{user_id}' is whitelisted into variation '#{whitelisted_variation_key}', which is not in the datafile."
        )
        return nil
      end

      @config.logger.log(
        Logger::INFO,
        "User '#{user_id}' is whitelisted into variation '#{whitelisted_variation_key}' of experiment '#{experiment_key}'."
      )
      whitelisted_variation_id
    end

    def get_saved_variation_id(experiment_id, user_profile)
      # Retrieve variation ID of stored bucketing decision for a given experiment from a given user profile
      #
      # experiment_id - String experiment ID
      # user_profile - Hash user profile
      #
      # Returns string variation ID (nil if no decision is found)
      return nil unless user_profile[:experiment_bucket_map]

      decision = user_profile[:experiment_bucket_map][experiment_id]
      return nil unless decision
      variation_id = decision[:variation_id]
      return variation_id if @config.variation_id_exists?(experiment_id, variation_id)

      @config.logger.log(
        Logger::INFO,
        "User '#{user_profile['user_id']}' was previously bucketed into variation ID '#{variation_id}' for experiment '#{experiment_id}', but no matching variation was found. Re-bucketing user."
      )
      nil
    end

    def get_user_profile(user_id)
      # Determine if a user is forced into a variation for the given experiment and return the ID of that variation
      #
      # user_id - String ID for the user
      #
      # Returns Hash stored user profile (or a default one if lookup fails or user profile service not provided)

      user_profile = {
        :user_id => user_id,
        :experiment_bucket_map => {}
      }

      return user_profile unless @user_profile_service

      begin
        user_profile = @user_profile_service.lookup(user_id) || user_profile
      rescue => e
        @config.logger.log(Logger::ERROR, "Error while looking up user profile for user ID '#{user_id}': #{e}.")
      end

      user_profile
    end

    def save_user_profile(user_profile, experiment_id, variation_id)
      # Save a given bucketing decision to a given user profile
      #
      # user_profile - Hash user profile
      # experiment_id - String experiment ID
      # variation_id - String variation ID

      return unless @user_profile_service

      user_id = user_profile[:user_id]
      begin
        user_profile[:experiment_bucket_map][experiment_id] = {
          variation_id: variation_id
        }
        @user_profile_service.save(user_profile)
        @config.logger.log(Logger::INFO, "Saved variation ID #{variation_id} of experiment ID #{experiment_id} for user '#{user_id}'.")
      rescue => e
        @config.logger.log(Logger::ERROR, "Error while saving user profile for user ID '#{user_id}': #{e}.")
      end
    end

    def get_bucketing_id(user_id, attributes)
      # Gets the Bucketing Id for Bucketing
      #
      # user_id - String user ID
      # attributes - Hash user attributes
      # By default, the bucketing ID should be the user ID
      bucketing_id = user_id

      # If the bucketing ID key is defined in attributes, then use that in place of the userID
      if attributes && attributes[RESERVED_ATTRIBUTE_KEY_BUCKETING_ID].is_a?(String)
        unless attributes[RESERVED_ATTRIBUTE_KEY_BUCKETING_ID].empty?
          bucketing_id = attributes[RESERVED_ATTRIBUTE_KEY_BUCKETING_ID]
          @config.logger.log(Logger::DEBUG, "Setting the bucketing ID '#{bucketing_id}'")
        end
      end
      bucketing_id
    end
  end
end
