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
  class DecisionService
    # Optimizely's decision service that determines into which variation of an experiment a user will be allocated.
    #
    # The decision service contains all logic relating to how a user bucketing decisions is made.
    # This includes all of the following (in order):
    #
    # 1. Checking experiment status
    # 2. Checking force bucketing
    # 3. Checking whitelisting
    # 4. Checking user profile service for past bucketing decisions (sticky bucketing)
    # 5. Checking audience targeting
    # 6. Using Murmurhash3 to bucket the user

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
      variation = @bucketer.bucket(experiment, user_id)
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
      unless decision.nil?
        return decision
      end

      feature_flag_key = feature_flag['key']
      variation = get_variation_for_feature_rollout(feature_flag, user_id, attributes)
      if variation
        @config.logger.log(
          Logger::INFO,
          "User '#{user_id}' is in the rollout for feature flag '#{feature_flag_key}'."
        )
        # return decision with nil experiment so we don't track impressions for it
        return {
          'experiment' => nil,
          'variation' => variation
        }
      else
        @config.logger.log(
          Logger::INFO,
          "User '#{user_id}' is not in the rollout for feature flag '#{feature_flag_key}'."
        )
      end

      return nil
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
      unless feature_flag['experimentIds'].empty?
        # check if experiment is part of mutex group
        experiment_id = feature_flag['experimentIds'][0]
        experiment = @config.experiment_id_map[experiment_id]
        unless experiment
          @config.logger.log(
            Logger::DEBUG,
            "Feature flag experiment with ID '#{experiment_id}' is not in the datafile."
          )
          return nil
        end

        group_id = experiment['groupId']
        # if experiment is part of mutex group we first determine which experiment (if any) in the group the user is part of
        if group_id and @config.group_key_map.has_key?(group_id)
          group = @config.group_key_map[group_id]
          bucketed_experiment_id = @bucketer.find_bucket(user_id, group_id, group['trafficAllocation'])
          if bucketed_experiment_id.nil?
            @config.logger.log(
              Logger::INFO,
              "The user '#{user_id}' is not bucketed into any of the experiments on the feature '#{feature_flag_key}'."
            )
            return nil
          end
        else
          bucketed_experiment_id = experiment_id
        end

        if feature_flag['experimentIds'].include?(bucketed_experiment_id)
          experiment = @config.experiment_id_map[bucketed_experiment_id]
          experiment_key = experiment['key']
          variation_id = get_variation(experiment_key, user_id, attributes)
          unless variation_id.nil?
            variation = @config.variation_id_map[experiment_key][variation_id]
            @config.logger.log(
              Logger::INFO,
              "The user '#{user_id}' is bucketed into experiment '#{experiment_key}' of feature '#{feature_flag_key}'."
            )
            return {
              'variation' => variation,
              'experiment' => experiment
            }
          else
            @config.logger.log(
              Logger::INFO,
              "The user '#{user_id}' is not bucketed into any of the experiments on the feature '#{feature_flag_key}'."
            )
          end
        end
      else
        @config.logger.log(
          Logger::DEBUG,
          "The feature flag '#{feature_flag_key}' is not used in any experiments."
        )
      end

      return nil
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

      rollout_id = feature_flag['rolloutId']
      if rollout_id.nil? or rollout_id.empty?
        feature_flag_key = feature_flag['key']
        @config.logger.log(
          Logger::DEBUG,
          "Feature flag '#{feature_flag_key}' is not part of a rollout."
        )
        return nil
      end

      rollout = @config.get_rollout_from_id(rollout_id)
      unless rollout.nil? or rollout['experiments'].empty?
        rollout_experiments = rollout['experiments']
        number_of_rules = rollout_experiments.length - 1

        # Go through each experiment in order and try to get the variation for the user
        for index in (0...number_of_rules)
          experiment = rollout_experiments[index]
          experiment_key = experiment['key']

          # Check that user meets audience conditions for targeting rule
          unless Audience.user_in_experiment?(@config, experiment, attributes)
            @config.logger.log(
              Logger::DEBUG,
              "User '#{user_id}' does not meet the conditions to be in experiment '#{experiment_key}'."
            )
            # move onto the next targeting rule
            next
          end

          @config.logger.log(
            Logger::DEBUG,
            "User '#{user_id}' meets conditions for targeting rule '#{index + 1}'."
          )
          variation = @bucketer.bucket(experiment, user_id)
          unless variation.nil?
            variation_key = variation['key']
            return variation
          end

          # User failed traffic allocation, jump to Everyone Else rule
          @config.logger.log(
            Logger::DEBUG,
            "User '#{user_id}' is not in the traffic group for the targeting rule. Checking 'Eveyrone Else' rule now."
          )
          break
        end

        # Evalute the "Everyone Else" rule, which is the last rule.
        everyone_else_experiment = rollout_experiments[number_of_rules]
        variation = @bucketer.bucket(everyone_else_experiment, user_id)
        unless variation.nil?
          @config.logger.log(
            Logger::DEBUG,
            "User '#{user_id}' meets conditions for targeting rule 'Everyone Else'."
          )
          return variation
        end

        @config.logger.log(
          Logger::DEBUG,
          "User '#{user_id}' does not meet conditions for targeting rule 'Everyone Else'."
        )
      end

      return nil
    end

    private

    def get_whitelisted_variation_id(experiment_key, user_id)
      # Determine if a user is white-listed into a variation for the given experiment and return the ID of that variation
      #
      # experiment_key - Key representing the experiment for which user is to be bucketed
      # user_id - ID for the user
      #
      # Returns variation ID into which user_id is white-listed (nil if no variation)

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
          :variation_id => variation_id
        }
        @user_profile_service.save(user_profile)
        @config.logger.log(Logger::INFO, "Saved variation ID #{variation_id} of experiment ID #{experiment_id} for user '#{user_id}'.")
      rescue => e
        @config.logger.log(Logger::ERROR, "Error while saving user profile for user ID '#{user_id}': #{e}.")
      end
    end
  end
end
