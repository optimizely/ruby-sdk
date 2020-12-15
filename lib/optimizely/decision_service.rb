# frozen_string_literal: true

#
#    Copyright 2017-2020, Optimizely and contributors
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
    # 1. Check experiment status
    # 2. Check forced bucketing
    # 3. Check whitelisting
    # 4. Check user profile service for past bucketing decisions (sticky bucketing)
    # 5. Check audience targeting
    # 6. Use Murmurhash3 to bucket the user

    attr_reader :bucketer

    # Hash of user IDs to a Hash of experiments to variations.
    # This contains all the forced variations set by the user by calling setForcedVariation.
    attr_reader :forced_variation_map

    Decision = Struct.new(:experiment, :variation, :source)

    DECISION_SOURCES = {
      'EXPERIMENT' => 'experiment',
      'FEATURE_TEST' => 'feature-test',
      'ROLLOUT' => 'rollout'
    }.freeze

    def initialize(logger, user_profile_service = nil)
      @logger = logger
      @user_profile_service = user_profile_service
      @bucketer = Bucketer.new(logger)
      @forced_variation_map = {}
    end

    def get_variation(project_config, experiment_key, user_id, attributes = nil, decide_options = [], decide_reasons = nil)
      # Determines variation into which user will be bucketed.
      #
      # project_config - project_config - Instance of ProjectConfig
      # experiment_key - Experiment for which visitor variation needs to be determined
      # user_id - String ID for user
      # attributes - Hash representing user attributes
      #
      # Returns variation ID where visitor will be bucketed
      #   (nil if experiment is inactive or user does not meet audience conditions)

      # By default, the bucketing ID should be the user ID
      bucketing_id = get_bucketing_id(user_id, attributes, decide_reasons)
      # Check to make sure experiment is active
      experiment = project_config.get_experiment_from_key(experiment_key)
      return nil if experiment.nil?

      experiment_id = experiment['id']
      unless project_config.experiment_running?(experiment)
        message = "Experiment '#{experiment_key}' is not running."
        @logger.log(Logger::INFO, message)
        decide_reasons&.push(message)
        return nil
      end

      # Check if a forced variation is set for the user
      forced_variation = get_forced_variation(project_config, experiment_key, user_id, decide_reasons)
      return forced_variation['id'] if forced_variation

      # Check if user is in a white-listed variation
      whitelisted_variation_id = get_whitelisted_variation_id(project_config, experiment_key, user_id, decide_reasons)
      return whitelisted_variation_id if whitelisted_variation_id

      should_ignore_user_profile_service = decide_options.include? Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE
      # Check for saved bucketing decisions if decide_options do not include ignoreUserProfileService
      unless should_ignore_user_profile_service
        user_profile = get_user_profile(user_id, decide_reasons)
        saved_variation_id = get_saved_variation_id(project_config, experiment_id, user_profile, decide_reasons)
        if saved_variation_id
          message = "Returning previously activated variation ID #{saved_variation_id} of experiment '#{experiment_key}' for user '#{user_id}' from user profile."
          @logger.log(Logger::INFO, message)
          decide_reasons&.push(message)
          return saved_variation_id
        end
      end

      # Check audience conditions
      unless Audience.user_meets_audience_conditions?(project_config, experiment, attributes, @logger)
        message = "User '#{user_id}' does not meet the conditions to be in experiment '#{experiment_key}'."
        @logger.log(Logger::INFO, message)
        decide_reasons&.push(message)
        return nil
      end

      # Bucket normally
      variation, bucket_reasons = @bucketer.bucket(project_config, experiment, bucketing_id, user_id)
      decide_reasons&.push(*bucket_reasons)
      variation_id = variation ? variation['id'] : nil

      message = ''
      if variation_id
        variation_key = variation['key']
        message = "User '#{user_id}' is in variation '#{variation_key}' of experiment '#{experiment_key}'."
      else
        message = "User '#{user_id}' is in no variation."
      end
      @logger.log(Logger::INFO, message)
      decide_reasons&.push(message)

      # Persist bucketing decision
      save_user_profile(user_profile, experiment_id, variation_id) unless should_ignore_user_profile_service
      variation_id
    end

    def get_variation_for_feature(project_config, feature_flag, user_id, attributes = nil, decide_options = [], decide_reasons = nil)
      # Get the variation the user is bucketed into for the given FeatureFlag.
      #
      # project_config - project_config - Instance of ProjectConfig
      # feature_flag - The feature flag the user wants to access
      # user_id - String ID for the user
      # attributes - Hash representing user attributes
      #
      # Returns Decision struct (nil if the user is not bucketed into any of the experiments on the feature)

      # check if the feature is being experiment on and whether the user is bucketed into the experiment
      decision = get_variation_for_feature_experiment(project_config, feature_flag, user_id, attributes, decide_options, decide_reasons)
      return decision unless decision.nil?

      decision = get_variation_for_feature_rollout(project_config, feature_flag, user_id, attributes, decide_reasons)

      decision
    end

    def get_variation_for_feature_experiment(project_config, feature_flag, user_id, attributes = nil, decide_options = [], decide_reasons = nil)
      # Gets the variation the user is bucketed into for the feature flag's experiment.
      #
      # project_config - project_config - Instance of ProjectConfig
      # feature_flag - The feature flag the user wants to access
      # user_id - String ID for the user
      # attributes - Hash representing user attributes
      #
      # Returns Decision struct (nil if the user is not bucketed into any of the experiments on the feature)
      # or nil if the user is not bucketed into any of the experiments on the feature
      feature_flag_key = feature_flag['key']
      if feature_flag['experimentIds'].empty?
        message = "The feature flag '#{feature_flag_key}' is not used in any experiments."
        @logger.log(Logger::DEBUG, message)
        decide_reasons&.push(message)
        return nil
      end

      # Evaluate each experiment and return the first bucketed experiment variation
      feature_flag['experimentIds'].each do |experiment_id|
        experiment = project_config.experiment_id_map[experiment_id]
        unless experiment
          message = "Feature flag experiment with ID '#{experiment_id}' is not in the datafile."
          @logger.log(Logger::DEBUG, message)
          decide_reasons&.push(message)
          return nil
        end

        experiment_key = experiment['key']
        variation_id = get_variation(project_config, experiment_key, user_id, attributes, decide_options, decide_reasons)

        next unless variation_id

        variation = project_config.variation_id_map[experiment_key][variation_id]

        return Decision.new(experiment, variation, DECISION_SOURCES['FEATURE_TEST'])
      end

      message = "The user '#{user_id}' is not bucketed into any of the experiments on the feature '#{feature_flag_key}'."
      @logger.log(Logger::INFO, message)
      decide_reasons&.push(message)

      nil
    end

    def get_variation_for_feature_rollout(project_config, feature_flag, user_id, attributes = nil, decide_reasons = nil)
      # Determine which variation the user is in for a given rollout.
      # Returns the variation of the first experiment the user qualifies for.
      #
      # project_config - project_config - Instance of ProjectConfig
      # feature_flag - The feature flag the user wants to access
      # user_id - String ID for the user
      # attributes - Hash representing user attributes
      #
      # Returns the Decision struct or nil if not bucketed into any of the targeting rules
      bucketing_id = get_bucketing_id(user_id, attributes, decide_reasons)
      rollout_id = feature_flag['rolloutId']
      if rollout_id.nil? || rollout_id.empty?
        feature_flag_key = feature_flag['key']
        message = "Feature flag '#{feature_flag_key}' is not used in a rollout."
        @logger.log(Logger::DEBUG, message)
        decide_reasons&.push(message)
        return nil
      end

      rollout = project_config.get_rollout_from_id(rollout_id)
      if rollout.nil?
        message = "Rollout with ID '#{rollout_id}' is not in the datafile '#{feature_flag['key']}'"
        @logger.log(Logger::DEBUG, message)
        decide_reasons&.push(message)
        return nil
      end

      return nil if rollout['experiments'].empty?

      rollout_rules = rollout['experiments']
      number_of_rules = rollout_rules.length - 1

      # Go through each experiment in order and try to get the variation for the user
      number_of_rules.times do |index|
        rollout_rule = rollout_rules[index]
        logging_key = index + 1

        # Check that user meets audience conditions for targeting rule
        unless Audience.user_meets_audience_conditions?(project_config, rollout_rule, attributes, @logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', logging_key)
          message = "User '#{user_id}' does not meet the audience conditions for targeting rule '#{logging_key}'."
          @logger.log(Logger::DEBUG, message)
          decide_reasons&.push(message)
          # move onto the next targeting rule
          next
        end

        message = "User '#{user_id}' meets the audience conditions for targeting rule '#{logging_key}'."
        @logger.log(Logger::DEBUG, message)
        decide_reasons&.push(message)

        # Evaluate if user satisfies the traffic allocation for this rollout rule
        variation, bucket_reasons = @bucketer.bucket(project_config, rollout_rule, bucketing_id, user_id)
        decide_reasons&.push(*bucket_reasons)
        return Decision.new(rollout_rule, variation, DECISION_SOURCES['ROLLOUT']) unless variation.nil?

        break
      end

      # get last rule which is the everyone else rule
      everyone_else_experiment = rollout_rules[number_of_rules]
      logging_key = 'Everyone Else'
      # Check that user meets audience conditions for last rule
      unless Audience.user_meets_audience_conditions?(project_config, everyone_else_experiment, attributes, @logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', logging_key)
        message = "User '#{user_id}' does not meet the audience conditions for targeting rule '#{logging_key}'."
        @logger.log(Logger::DEBUG, message)
        decide_reasons&.push(message)
        return nil
      end

      message = "User '#{user_id}' meets the audience conditions for targeting rule '#{logging_key}'."
      @logger.log(Logger::DEBUG, message)
      decide_reasons&.push(message)

      variation, bucket_reasons = @bucketer.bucket(project_config, everyone_else_experiment, bucketing_id, user_id)
      decide_reasons&.push(*bucket_reasons)
      return Decision.new(everyone_else_experiment, variation, DECISION_SOURCES['ROLLOUT']) unless variation.nil?

      nil
    end

    def set_forced_variation(project_config, experiment_key, user_id, variation_key)
      # Sets a Hash of user IDs to a Hash of experiments to forced variations.
      #
      # project_config - Instance of ProjectConfig
      # experiment_key - String Key for experiment
      # user_id - String ID for user.
      # variation_key - String Key for variation. If null, then clear the existing experiment-to-variation mapping
      #
      # Returns a boolean value that indicates if the set completed successfully

      experiment = project_config.get_experiment_from_key(experiment_key)
      experiment_id = experiment['id'] if experiment
      #  check if the experiment exists in the datafile
      return false if experiment_id.nil? || experiment_id.empty?

      #  clear the forced variation if the variation key is null
      if variation_key.nil?
        @forced_variation_map[user_id].delete(experiment_id) if @forced_variation_map.key? user_id
        @logger.log(Logger::DEBUG, "Variation mapped to experiment '#{experiment_key}' has been removed for user "\
                    "'#{user_id}'.")
        return true
      end

      variation_id = project_config.get_variation_id_from_key(experiment_key, variation_key)

      #  check if the variation exists in the datafile
      unless variation_id
        #  this case is logged in get_variation_id_from_key
        return false
      end

      @forced_variation_map[user_id] = {} unless @forced_variation_map.key? user_id
      @forced_variation_map[user_id][experiment_id] = variation_id
      @logger.log(Logger::DEBUG, "Set variation '#{variation_id}' for experiment '#{experiment_id}' and "\
                  "user '#{user_id}' in the forced variation map.")
      true
    end

    def get_forced_variation(project_config, experiment_key, user_id, decide_reasons = nil)
      # Gets the forced variation for the given user and experiment.
      #
      # project_config - Instance of ProjectConfig
      # experiment_key - String Key for experiment
      # user_id - String ID for user
      #
      # Returns Variation The variation which the given user and experiment should be forced into

      unless @forced_variation_map.key? user_id
        message = "User '#{user_id}' is not in the forced variation map."
        @logger.log(Logger::DEBUG, message)
        decide_reasons&.push(message)
        return nil
      end

      experiment_to_variation_map = @forced_variation_map[user_id]
      experiment = project_config.get_experiment_from_key(experiment_key)
      experiment_id = experiment['id'] if experiment
      # check for nil and empty string experiment ID
      # this case is logged in get_experiment_from_key
      return nil if experiment_id.nil? || experiment_id.empty?

      unless experiment_to_variation_map.key? experiment_id
        message = "No experiment '#{experiment_key}' mapped to user '#{user_id}' in the forced variation map."
        @logger.log(Logger::DEBUG, message)
        decide_reasons&.push(message)
        return nil
      end

      variation_id = experiment_to_variation_map[experiment_id]
      variation_key = ''
      variation = project_config.get_variation_from_id(experiment_key, variation_id)
      variation_key = variation['key'] if variation

      # check if the variation exists in the datafile
      # this case is logged in get_variation_from_id
      return nil if variation_key.empty?

      message = "Variation '#{variation_key}' is mapped to experiment '#{experiment_key}' and user '#{user_id}' in the forced variation map"
      @logger.log(Logger::DEBUG, message)
      decide_reasons&.push(message)

      variation
    end

    private

    def get_whitelisted_variation_id(project_config, experiment_key, user_id, decide_reasons = nil)
      # Determine if a user is whitelisted into a variation for the given experiment and return the ID of that variation
      #
      # project_config - project_config - Instance of ProjectConfig
      # experiment_key - Key representing the experiment for which user is to be bucketed
      # user_id - ID for the user
      #
      # Returns variation ID into which user_id is whitelisted (nil if no variation)

      whitelisted_variations = project_config.get_whitelisted_variations(experiment_key)

      return nil unless whitelisted_variations

      whitelisted_variation_key = whitelisted_variations[user_id]

      return nil unless whitelisted_variation_key

      whitelisted_variation_id = project_config.get_variation_id_from_key(experiment_key, whitelisted_variation_key)

      unless whitelisted_variation_id
        message = "User '#{user_id}' is whitelisted into variation '#{whitelisted_variation_key}', which is not in the datafile."
        @logger.log(Logger::INFO, message)
        decide_reasons&.push(message)
        return nil
      end

      message = "User '#{user_id}' is whitelisted into variation '#{whitelisted_variation_key}' of experiment '#{experiment_key}'."
      @logger.log(Logger::INFO, message)
      decide_reasons&.push(message)

      whitelisted_variation_id
    end

    def get_saved_variation_id(project_config, experiment_id, user_profile, decide_reasons = nil)
      # Retrieve variation ID of stored bucketing decision for a given experiment from a given user profile
      #
      # project_config - project_config - Instance of ProjectConfig
      # experiment_id - String experiment ID
      # user_profile - Hash user profile
      #
      # Returns string variation ID (nil if no decision is found)
      return nil unless user_profile[:experiment_bucket_map]

      decision = user_profile[:experiment_bucket_map][experiment_id]
      return nil unless decision

      variation_id = decision[:variation_id]
      return variation_id if project_config.variation_id_exists?(experiment_id, variation_id)

      message = "User '#{user_profile['user_id']}' was previously bucketed into variation ID '#{variation_id}' for experiment '#{experiment_id}', but no matching variation was found. Re-bucketing user."
      @logger.log(Logger::INFO, message)
      decide_reasons&.push(message)

      nil
    end

    def get_user_profile(user_id, decide_reasons = nil)
      # Determine if a user is forced into a variation for the given experiment and return the ID of that variation
      #
      # user_id - String ID for the user
      #
      # Returns Hash stored user profile (or a default one if lookup fails or user profile service not provided)

      user_profile = {
        user_id: user_id,
        experiment_bucket_map: {}
      }

      return user_profile unless @user_profile_service

      begin
        user_profile = @user_profile_service.lookup(user_id) || user_profile
      rescue => e
        message = "Error while looking up user profile for user ID '#{user_id}': #{e}."
        @logger.log(Logger::ERROR, message)
        decide_reasons&.push(message)
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
        @logger.log(Logger::INFO, "Saved variation ID #{variation_id} of experiment ID #{experiment_id} for user '#{user_id}'.")
      rescue => e
        @logger.log(Logger::ERROR, "Error while saving user profile for user ID '#{user_id}': #{e}.")
      end
    end

    def get_bucketing_id(user_id, attributes, decide_reasons = nil)
      # Gets the Bucketing Id for Bucketing
      #
      # user_id - String user ID
      # attributes - Hash user attributes
      # Returns String representing bucketing ID if it is a String type in attributes else return user ID

      return user_id unless attributes

      bucketing_id = attributes[Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID']]

      if bucketing_id
        return bucketing_id if bucketing_id.is_a?(String)

        message = 'Bucketing ID attribute is not a string. Defaulted to user ID.'
        @logger.log(Logger::WARN, message)
        decide_reasons&.push(message)
      end
      user_id
    end
  end
end
