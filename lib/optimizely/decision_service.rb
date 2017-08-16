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
require 'pp'

module Optimizely
  class DecisionService
    # Optimizely's decision service that determines into which variation of an experiment a user will be allocated.
    #
    # The decision service contains all logic relating to how a user bucketing decisions is made.
    # This includes all of the following (in order):
    #
    # 1. Checking experiment status
    # 2. Checking whitelisting
    # 3. Checking user profile service for past bucketing decisions (sticky bucketing)
    # 3. Checking audience targeting
    # 4. Using Murmurhash3 to bucket the user

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
      unless @config.experiment_running?(experiment_key)
        @config.logger.log(Logger::INFO, "Experiment '#{experiment_key}' is not running.")
        return nil
      end

      experiment_id = @config.get_experiment_id(experiment_key)

      # Check if user is in a forced variation
      forced_variation_id = get_forced_variation_id(experiment_key, user_id)
      return forced_variation_id if forced_variation_id

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
      unless Audience.user_in_experiment?(@config, experiment_key, attributes)
        @config.logger.log(
          Logger::INFO,
          "User '#{user_id}' does not meet the conditions to be in experiment '#{experiment_key}'."
        )
        return nil
      end

      # Bucket normally
      variation_id = @bucketer.bucket(experiment_key, user_id)

      # Persist bucketing decision
      save_user_profile(user_profile, experiment_id, variation_id)
      variation_id
    end

    def get_variation_for_feature(feature_flag, user_id, attributes = nil)
      # Get the variation the user is bucketed into for the given FeatureFlag.
      # This will bucket the user in the following order:
      #
      # A. The feature is associated with an experiment
      #   1. Try to bucket the user into those experiments.
      #   2. If the user is not bucketed in any experiments,
      #      we check if the feature is part of a rollout.
      #   3. If the feature is part of a rollout, we try to bucket the user into
      #      the experiments in the rollout.
      #   4. If the feature is not part of a rollout, we return nil.
      #
      # B. The feature is no associated with any experiments
      #   1. If the feature is part of a rollout, we try to bucker the user into
      #      the experiments in the rollout.
      #   2. Else we return nil.
      #
      # feature_flag - The feature flag the user wants to access
      # user_id - String ID for the user
      # attributes - Hash representing user attributes
      #
      # Returns variation where visitor will be bucketed (nil if the user is not bucketed into any of the experiments in the feature)

      feature_flag_key = feature_flag['key']
      # check if the feature is being experiment on and whether the user is bucketed into the experiment
      unless feature_flag['experimentIds'].empty?
        feature_flag['experimentIds'].each do |experiment_id|
          if @config.experiment_id_map.has_key?(experiment_id)
            experiment = @config.experiment_id_map[experiment_id]
            variation_id = get_variation(experiment['key'], user_id, attributes)
            unless variation_id.nil?
              return @config.variation_id_map[variation_id]
            end
          else
            @config.logger.log(
              Logger::DEBUG,
              "Feature flag experiment with id '#{experiment_id}' is not in the datafile."
            )
          end
        end
        @config.logger.log(
          Logger::INFO,
          "The user '#{user_id}' is not bucketed into any of the experiments in the feature '#{feature_flag_key}'."
        )
      else
        @config.logger.log(
          Logger::DEBUG,
          "The feature flag '#{feature_flag_key}' is not used in any experiments."
        )
      end

      # next check if the user feature being rolled out and whether the user is part of the rollout
      rollout_id = feature_flag['rolloutId']
      unless rollout_id.nil? or rollout_id.empty?
        if @config.rollout_id_map.has_key?(rollout_id)
          rollout = @config.rollout_id_map[rollout_id]
          rollout_experiments = rollout['experiments']
          rollout_experiments.each do |experiment|
            experiment_key = experiment['key']
            variation_id = get_variation(experiment_key, user_id, attributes)
            unless variation_id.nil?
              @config.logger.log(
                Logger::INFO,
                "User '#{user_id}' is in rollout with id '#{rollout_id}' for feature flag '#{feature_flag_key}'."
              )
              variation = @config.variation_id_map[experiment_key][variation_id]
              return variation
            end
          end
          @config.logger.log(
            Logger::INFO,
            "User '#{user_id}' is not part of the rollout with id '#{rollout_id}' for feature flag '#{feature_flag_key}'."
          )
        else
          @config.logger.log(
            Logger::DEBUG,
            "Rollout with id '#{rollout_id}' is not in the datafile."
          )
        end
      else
        @config.logger.log(
          Logger::DEBUG,
          "The feature flag '#{feature_flag_key}' is not part of a rollout."
        )
      end

      return nil
    end

    private

    def get_forced_variation_id(experiment_key, user_id)
      # Determine if a user is forced into a variation for the given experiment and return the ID of that variation
      #
      # experiment_key - Key representing the experiment for which user is to be bucketed
      # user_id - ID for the user
      #
      # Returns variation ID into which user_id is forced (nil if no variation)

      forced_variations = @config.get_forced_variations(experiment_key)

      return nil unless forced_variations

      forced_variation_key = forced_variations[user_id]

      return nil unless forced_variation_key

      forced_variation_id = @config.get_variation_id_from_key(experiment_key, forced_variation_key)

      unless forced_variation_id
        @config.logger.log(
          Logger::INFO,
          "User '#{user_id}' is whitelisted into variation '#{forced_variation_key}', which is not in the datafile."
        )
        return nil
      end

      @config.logger.log(
        Logger::INFO,
        "User '#{user_id}' is whitelisted into variation '#{forced_variation_key}' of experiment '#{experiment_key}'."
      )
      forced_variation_id
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
