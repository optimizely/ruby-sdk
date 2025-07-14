# frozen_string_literal: true

#
#    Copyright 2017-2022, Optimizely and contributors
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

    Decision = Struct.new(:experiment, :variation, :source, :cmab_uuid)
    CmabDecisionResult = Struct.new(:error, :result, :reasons)
    VariationResult = Struct.new(:cmab_uuid, :error, :reasons, :variation)
    DecisionResult = Struct.new(:decision, :error, :reasons)

    DECISION_SOURCES = {
      'EXPERIMENT' => 'experiment',
      'FEATURE_TEST' => 'feature-test',
      'ROLLOUT' => 'rollout'
    }.freeze

    def initialize(logger, cmab_service, user_profile_service = nil)
      @logger = logger
      @user_profile_service = user_profile_service
      @bucketer = Bucketer.new(logger)
      @forced_variation_map = {}
      @cmab_service = cmab_service
    end

    def get_variation(project_config, experiment_id, user_context, user_profile_tracker = nil, decide_options = [], reasons = [])
      # Determines variation into which user will be bucketed.
      #
      # project_config - project_config - Instance of ProjectConfig
      # experiment_id - Experiment for which visitor variation needs to be determined
      # user_context - Optimizely user context instance
      # user_profile_tracker: Tracker for reading and updating user profile of the user.
      # reasons: Decision reasons.
      #
      # Returns variation ID where visitor will be bucketed
      #   (nil if experiment is inactive or user does not meet audience conditions)
      user_profile_tracker = UserProfileTracker.new(user_context.user_id, @user_profile_service, @logger) unless user_profile_tracker.is_a?(Optimizely::UserProfileTracker)
      decide_reasons = []
      decide_reasons.push(*reasons)
      user_id = user_context.user_id
      attributes = user_context.user_attributes
      # By default, the bucketing ID should be the user ID
      bucketing_id, bucketing_id_reasons = get_bucketing_id(user_id, attributes)
      decide_reasons.push(*bucketing_id_reasons)
      # Check to make sure experiment is active
      experiment = project_config.get_experiment_from_id(experiment_id)
      return nil, decide_reasons if experiment.nil?

      experiment_key = experiment['key']
      unless project_config.experiment_running?(experiment)
        message = "Experiment '#{experiment_key}' is not running."
        @logger.log(Logger::INFO, message)
        decide_reasons.push(message)
        return nil, decide_reasons
      end

      # Check if a forced variation is set for the user
      forced_variation, reasons_received = get_forced_variation(project_config, experiment['key'], user_id)
      decide_reasons.push(*reasons_received)
      return forced_variation['id'], decide_reasons if forced_variation

      # Check if user is in a white-listed variation
      whitelisted_variation_id, reasons_received = get_whitelisted_variation_id(project_config, experiment_id, user_id)
      decide_reasons.push(*reasons_received)
      return whitelisted_variation_id, decide_reasons if whitelisted_variation_id

      should_ignore_user_profile_service = decide_options.include? Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE
      # Check for saved bucketing decisions if decide_options do not include ignoreUserProfileService
      unless should_ignore_user_profile_service && user_profile_tracker
        saved_variation_id, reasons_received = get_saved_variation_id(project_config, experiment_id, user_profile_tracker.user_profile)
        decide_reasons.push(*reasons_received)
        if saved_variation_id
          message = "Returning previously activated variation ID #{saved_variation_id} of experiment '#{experiment_key}' for user '#{user_id}' from user profile."
          @logger.log(Logger::INFO, message)
          decide_reasons.push(message)
          return saved_variation_id, decide_reasons
        end
      end

      # Check audience conditions
      user_meets_audience_conditions, reasons_received = Audience.user_meets_audience_conditions?(project_config, experiment, user_context, @logger)
      decide_reasons.push(*reasons_received)
      unless user_meets_audience_conditions
        message = "User '#{user_id}' does not meet the conditions to be in experiment '#{experiment_key}'."
        @logger.log(Logger::INFO, message)
        decide_reasons.push(message)
        return nil, decide_reasons
      end

      # Bucket normally
      variation, bucket_reasons = @bucketer.bucket(project_config, experiment, bucketing_id, user_id)
      decide_reasons.push(*bucket_reasons)
      variation_id = variation ? variation['id'] : nil

      message = ''
      if variation_id
        variation_key = variation['key']
        message = "User '#{user_id}' is in variation '#{variation_key}' of experiment '#{experiment_id}'."
      else
        message = "User '#{user_id}' is in no variation."
      end
      @logger.log(Logger::INFO, message)
      decide_reasons.push(message)

      # Persist bucketing decision
      user_profile_tracker.update_user_profile(experiment_id, variation_id) unless should_ignore_user_profile_service && user_profile_tracker
      [variation_id, decide_reasons]
    end

    def get_variation_for_feature(project_config, feature_flag, user_context, decide_options = [])
      # Get the variation the user is bucketed into for the given FeatureFlag.
      #
      # project_config - project_config - Instance of ProjectConfig
      # feature_flag - The feature flag the user wants to access
      # user_context - Optimizely user context instance
      #
      # Returns Decision struct (nil if the user is not bucketed into any of the experiments on the feature)
      get_variations_for_feature_list(project_config, [feature_flag], user_context, decide_options).first
    end

    def get_variations_for_feature_list(project_config, feature_flags, user_context, decide_options = [])
      # Returns the list of experiment/variation the user is bucketed in for the given list of features.
      #
      # Args:
      #   project_config: Instance of ProjectConfig.
      #   feature_flags: Array of features for which we are determining if it is enabled or not for the given user.
      #   user_context: User context for user.
      #   decide_options: Decide options.
      #
      # Returns:
      #   Array of Decision struct.
      ignore_ups = decide_options.include? Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE
      user_profile_tracker = nil
      unless ignore_ups && @user_profile_service
        user_profile_tracker = UserProfileTracker.new(user_context.user_id, @user_profile_service, @logger)
        user_profile_tracker.load_user_profile
      end
      decisions = []
      feature_flags.each do |feature_flag|
        decide_reasons = []
        # check if the feature is being experiment on and whether the user is bucketed into the experiment
        decision, reasons_received = get_variation_for_feature_experiment(project_config, feature_flag, user_context, user_profile_tracker, decide_options)
        decide_reasons.push(*reasons_received)
        if decision
          decisions << [decision, decide_reasons]
        else
          # Proceed to rollout if the decision is nil
          rollout_decision, reasons_received = get_variation_for_feature_rollout(project_config, feature_flag, user_context)
          decide_reasons.push(*reasons_received)
          decisions << [rollout_decision, decide_reasons]
        end
      end
      user_profile_tracker&.save_user_profile
      decisions
    end

    def get_variation_for_feature_experiment(project_config, feature_flag, user_context, user_profile_tracker, decide_options = [])
      # Gets the variation the user is bucketed into for the feature flag's experiment.
      #
      # project_config - project_config - Instance of ProjectConfig
      # feature_flag - The feature flag the user wants to access
      # user_context - Optimizely user context instance
      #
      # Returns Decision struct (nil if the user is not bucketed into any of the experiments on the feature)
      # or nil if the user is not bucketed into any of the experiments on the feature
      decide_reasons = []
      user_id = user_context.user_id
      feature_flag_key = feature_flag['key']
      if feature_flag['experimentIds'].empty?
        message = "The feature flag '#{feature_flag_key}' is not used in any experiments."
        @logger.log(Logger::DEBUG, message)
        decide_reasons.push(message)
        return nil, decide_reasons
      end

      # Evaluate each experiment and return the first bucketed experiment variation
      feature_flag['experimentIds'].each do |experiment_id|
        experiment = project_config.experiment_id_map[experiment_id]
        unless experiment
          message = "Feature flag experiment with ID '#{experiment_id}' is not in the datafile."
          @logger.log(Logger::DEBUG, message)
          decide_reasons.push(message)
          return nil, decide_reasons
        end

        experiment_id = experiment['id']
        variation_id, reasons_received = get_variation_from_experiment_rule(project_config, feature_flag_key, experiment, user_context, user_profile_tracker, decide_options)
        decide_reasons.push(*reasons_received)

        next unless variation_id

        variation = project_config.get_variation_from_id_by_experiment_id(experiment_id, variation_id)
        variation = project_config.get_variation_from_flag(feature_flag['key'], variation_id, 'id') if variation.nil?

        return Decision.new(experiment, variation, DECISION_SOURCES['FEATURE_TEST']), decide_reasons
      end

      message = "The user '#{user_id}' is not bucketed into any of the experiments on the feature '#{feature_flag_key}'."
      @logger.log(Logger::INFO, message)
      decide_reasons.push(message)

      [nil, decide_reasons]
    end

    def get_variation_for_feature_rollout(project_config, feature_flag, user_context)
      # Determine which variation the user is in for a given rollout.
      # Returns the variation of the first experiment the user qualifies for.
      #
      # project_config - project_config - Instance of ProjectConfig
      # feature_flag - The feature flag the user wants to access
      # user_context - Optimizely user context instance
      #
      # Returns the Decision struct or nil if not bucketed into any of the targeting rules
      decide_reasons = []

      rollout_id = feature_flag['rolloutId']
      feature_flag_key = feature_flag['key']
      if rollout_id.nil? || rollout_id.empty?
        message = "Feature flag '#{feature_flag_key}' is not used in a rollout."
        @logger.log(Logger::DEBUG, message)
        decide_reasons.push(message)
        return nil, decide_reasons
      end

      rollout = project_config.get_rollout_from_id(rollout_id)
      if rollout.nil?
        message = "Rollout with ID '#{rollout_id}' is not in the datafile '#{feature_flag['key']}'"
        @logger.log(Logger::DEBUG, message)
        decide_reasons.push(message)
        return nil, decide_reasons
      end

      return nil, decide_reasons if rollout['experiments'].empty?

      index = 0
      rollout_rules = rollout['experiments']
      while index < rollout_rules.length
        variation, skip_to_everyone_else, reasons_received = get_variation_from_delivery_rule(project_config, feature_flag_key, rollout_rules, index, user_context)
        decide_reasons.push(*reasons_received)
        if variation
          rule = rollout_rules[index]
          feature_decision = Decision.new(rule, variation, DECISION_SOURCES['ROLLOUT'])
          return [feature_decision, decide_reasons]
        end

        index = skip_to_everyone_else ? (rollout_rules.length - 1) : (index + 1)
      end

      [nil, decide_reasons]
    end

    def get_variation_from_experiment_rule(project_config, flag_key, rule, user, user_profile_tracker, options = [])
      # Determine which variation the user is in for a given rollout.
      # Returns the variation from experiment rules.
      #
      # project_config - project_config - Instance of ProjectConfig
      # flag_key - The feature flag the user wants to access
      # rule - An experiment rule key
      # user - Optimizely user context instance
      #
      # Returns variation_id and reasons
      reasons = []

      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(flag_key, rule['key'])
      variation, forced_reasons = validated_forced_decision(project_config, context, user)
      reasons.push(*forced_reasons)

      return [variation['id'], reasons] if variation

      variation_id, response_reasons = get_variation(project_config, rule['id'], user, user_profile_tracker, options)
      reasons.push(*response_reasons)

      [variation_id, reasons]
    end

    def get_variation_from_delivery_rule(project_config, flag_key, rules, rule_index, user_context)
      # Determine which variation the user is in for a given rollout.
      # Returns the variation from delivery rules.
      #
      # project_config - project_config - Instance of ProjectConfig
      # flag_key - The feature flag the user wants to access
      # rule - An experiment rule key
      # user_context - Optimizely user context instance
      #
      # Returns variation, boolean to skip for eveyone else rule and reasons
      reasons = []
      skip_to_everyone_else = false
      rule = rules[rule_index]
      context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(flag_key, rule['key'])
      variation, forced_reasons = validated_forced_decision(project_config, context, user_context)
      reasons.push(*forced_reasons)

      return [variation, skip_to_everyone_else, reasons] if variation

      user_id = user_context.user_id
      attributes = user_context.user_attributes
      bucketing_id, bucketing_id_reasons = get_bucketing_id(user_id, attributes)
      reasons.push(*bucketing_id_reasons)

      everyone_else = (rule_index == rules.length - 1)

      logging_key = everyone_else ? 'Everyone Else' : (rule_index + 1).to_s

      user_meets_audience_conditions, reasons_received = Audience.user_meets_audience_conditions?(project_config, rule, user_context, @logger, 'ROLLOUT_AUDIENCE_EVALUATION_LOGS', logging_key)
      reasons.push(*reasons_received)
      unless user_meets_audience_conditions
        message = "User '#{user_id}' does not meet the conditions for targeting rule '#{logging_key}'."
        @logger.log(Logger::DEBUG, message)
        reasons.push(message)
        return [nil, skip_to_everyone_else, reasons]
      end

      message = "User '#{user_id}' meets the audience conditions for targeting rule '#{logging_key}'."
      @logger.log(Logger::DEBUG, message)
      reasons.push(message)
      bucket_variation, bucket_reasons = @bucketer.bucket(project_config, rule, bucketing_id, user_id)

      reasons.push(*bucket_reasons)

      if bucket_variation
        message = "User '#{user_id}' is in the traffic group of targeting rule '#{logging_key}'."
        @logger.log(Logger::DEBUG, message)
        reasons.push(message)
      elsif !everyone_else
        message = "User '#{user_id}' is not in the traffic group for targeting rule '#{logging_key}'."
        @logger.log(Logger::DEBUG, message)
        reasons.push(message)
        skip_to_everyone_else = true
      end
      [bucket_variation, skip_to_everyone_else, reasons]
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

      variation_id = project_config.get_variation_id_from_key_by_experiment_id(experiment_id, variation_key)

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

    def get_forced_variation(project_config, experiment_key, user_id)
      # Gets the forced variation for the given user and experiment.
      #
      # project_config - Instance of ProjectConfig
      # experiment_key - String key for experiment
      # user_id - String ID for user
      #
      # Returns Variation The variation which the given user and experiment should be forced into

      decide_reasons = []
      unless @forced_variation_map.key? user_id
        message = "User '#{user_id}' is not in the forced variation map."
        @logger.log(Logger::DEBUG, message)
        return nil, decide_reasons
      end

      experiment_to_variation_map = @forced_variation_map[user_id]
      experiment = project_config.get_experiment_from_key(experiment_key)
      experiment_id = experiment['id'] if experiment
      # check for nil and empty string experiment ID
      # this case is logged in get_experiment_from_key
      return nil, decide_reasons if experiment_id.nil? || experiment_id.empty?

      unless experiment_to_variation_map.key? experiment_id
        message = "No experiment '#{experiment_id}' mapped to user '#{user_id}' in the forced variation map."
        @logger.log(Logger::DEBUG, message)
        decide_reasons.push(message)
        return nil, decide_reasons
      end

      variation_id = experiment_to_variation_map[experiment_id]
      variation_key = ''
      variation = project_config.get_variation_from_id_by_experiment_id(experiment_id, variation_id)
      variation_key = variation['key'] if variation

      # check if the variation exists in the datafile
      # this case is logged in get_variation_from_id
      return nil, decide_reasons if variation_key.empty?

      message = "Variation '#{variation_key}' is mapped to experiment '#{experiment_id}' and user '#{user_id}' in the forced variation map"
      @logger.log(Logger::DEBUG, message)
      decide_reasons.push(message)

      [variation, decide_reasons]
    end

    def validated_forced_decision(project_config, context, user_context)
      decision = user_context.get_forced_decision(context)
      flag_key = context[:flag_key]
      rule_key = context[:rule_key]
      variation_key = decision ? decision[:variation_key] : decision
      reasons = []
      target = rule_key ? "flag (#{flag_key}), rule (#{rule_key})" : "flag (#{flag_key})"
      if variation_key
        variation = project_config.get_variation_from_flag(flag_key, variation_key, 'key')
        if variation
          reason = "Variation (#{variation_key}) is mapped to #{target} and user (#{user_context.user_id}) in the forced decision map."
          reasons.push(reason)
          return variation, reasons
        else
          reason = "Invalid variation is mapped to #{target} and user (#{user_context.user_id}) in the forced decision map."
          reasons.push(reason)
        end
      end

      [nil, reasons]
    end

    private

    def get_decision_for_cmab_experiment(project_config, experiment, user_context, bucketing_id, decide_options = [])
      # Determines the CMAB (Contextual Multi-Armed Bandit) decision for a given experiment and user context.
      #
      # This method first checks if the user is bucketed into the CMAB experiment based on traffic allocation.
      # If the user is not bucketed, it returns a CmabDecisionResult indicating exclusion.
      # If the user is bucketed, it attempts to fetch a CMAB decision using the CMAB service.
      # In case of errors during CMAB decision retrieval, it logs the error and returns a result indicating failure.
      #
      # @param project_config [ProjectConfig] The current project configuration.
      # @param experiment [Hash] The experiment configuration hash.
      # @param user_context [OptimizelyUserContext] The user context object containing user information.
      # @param bucketing_id [String] The bucketing ID used for traffic allocation.
      # @param decide_options [Array] Optional array of decision options.
      #
      # @return [CmabDecisionResult] The result of the CMAB decision process, including decision error status, decision data, and reasons.
      decide_reasons = []
      user_id = user_context.user_id

      # Check if user is in CMAB traffic allocation
      bucketed_entity_id, bucket_reasons = @bucketer.bucket_to_entity_id(
        project_config, experiment, user_id, bucketing_id
      )
      decide_reasons.extend(bucket_reasons)
      unless bucketed_entity_id
        message = "User \"#{user_context.user_id}\" not in CMAB experiment \"#{experiment['key']}\" due to traffic allocation."
        @logger.log(Logger::INFO, message)
        decide_reasons.push(message)
        CmabDecisionResult.new(false, nil, decide_reasons)
      end

      # User is in CMAB allocation, proceed to CMAB decision
      begin
        cmab_decision = @cmab_service.get_decision(
          project_config, user_context, experiment['id'], decide_options
        )
        CmabDecisionResult.new(false, cmab_decision, decide_reasons)
      rescue StandardError => e
        error_message = "Failed to fetch CMAB decision for experiment '#{experiment['key']}'"
        decide_reasons.push(error_message)
        @logger&.log(Logger::ERROR, "#{error_message} #{e}")
        CmabDecisionResult.new(true, nil, decide_reasons)
      end
    end

    def get_whitelisted_variation_id(project_config, experiment_id, user_id)
      # Determine if a user is whitelisted into a variation for the given experiment and return the ID of that variation
      #
      # project_config - project_config - Instance of ProjectConfig
      # experiment_key - Key representing the experiment for which user is to be bucketed
      # user_id - ID for the user
      #
      # Returns variation ID into which user_id is whitelisted (nil if no variation)

      whitelisted_variations = project_config.get_whitelisted_variations(experiment_id)

      return nil, nil unless whitelisted_variations

      whitelisted_variation_key = whitelisted_variations[user_id]

      return nil, nil unless whitelisted_variation_key

      whitelisted_variation_id = project_config.get_variation_id_from_key_by_experiment_id(experiment_id, whitelisted_variation_key)

      unless whitelisted_variation_id
        message = "User '#{user_id}' is whitelisted into variation '#{whitelisted_variation_key}', which is not in the datafile."
        @logger.log(Logger::INFO, message)
        return nil, message
      end

      message = "User '#{user_id}' is whitelisted into variation '#{whitelisted_variation_key}' of experiment '#{experiment_id}'."
      @logger.log(Logger::INFO, message)

      [whitelisted_variation_id, message]
    end

    def get_saved_variation_id(project_config, experiment_id, user_profile)
      # Retrieve variation ID of stored bucketing decision for a given experiment from a given user profile
      #
      # project_config - project_config - Instance of ProjectConfig
      # experiment_id - String experiment ID
      # user_profile - Hash user profile
      #
      # Returns string variation ID (nil if no decision is found)
      return nil, nil unless user_profile[:experiment_bucket_map]

      decision = user_profile[:experiment_bucket_map][experiment_id]
      return nil, nil unless decision

      variation_id = decision[:variation_id]
      return variation_id, nil if project_config.variation_id_exists?(experiment_id, variation_id)

      message = "User '#{user_profile[:user_id]}' was previously bucketed into variation ID '#{variation_id}' for experiment '#{experiment_id}', but no matching variation was found. Re-bucketing user."
      @logger.log(Logger::INFO, message)

      [nil, message]
    end

    def get_user_profile(user_id)
      # Determine if a user is forced into a variation for the given experiment and return the ID of that variation
      #
      # user_id - String ID for the user
      #
      # Returns Hash stored user profile (or a default one if lookup fails or user profile service not provided)

      user_profile = {
        user_id: user_id,
        experiment_bucket_map: {}
      }

      return user_profile, nil unless @user_profile_service

      message = nil
      begin
        user_profile = @user_profile_service.lookup(user_id) || user_profile
      rescue => e
        message = "Error while looking up user profile for user ID '#{user_id}': #{e}."
        @logger.log(Logger::ERROR, message)
      end

      [user_profile, message]
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

    def get_bucketing_id(user_id, attributes)
      # Gets the Bucketing Id for Bucketing
      #
      # user_id - String user ID
      # attributes - Hash user attributes
      # Returns String representing bucketing ID if it is a String type in attributes else return user ID

      return user_id, nil unless attributes

      bucketing_id = attributes[Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID']]

      if bucketing_id
        return bucketing_id, nil if bucketing_id.is_a?(String)

        message = 'Bucketing ID attribute is not a string. Defaulted to user ID.'
        @logger.log(Logger::WARN, message)
      end
      [user_id, message]
    end
  end
end
