# frozen_string_literal: true

#
#    Copyright 2016-2023, Optimizely and contributors
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
require_relative 'optimizely/audience'
require_relative 'optimizely/config/datafile_project_config'
require_relative 'optimizely/config_manager/http_project_config_manager'
require_relative 'optimizely/config_manager/static_project_config_manager'
require_relative 'optimizely/decide/optimizely_decide_option'
require_relative 'optimizely/decide/optimizely_decision'
require_relative 'optimizely/decide/optimizely_decision_message'
require_relative 'optimizely/decision_service'
require_relative 'optimizely/error_handler'
require_relative 'optimizely/event_builder'
require_relative 'optimizely/event/batch_event_processor'
require_relative 'optimizely/event/event_factory'
require_relative 'optimizely/event/user_event_factory'
require_relative 'optimizely/event_dispatcher'
require_relative 'optimizely/exceptions'
require_relative 'optimizely/helpers/constants'
require_relative 'optimizely/helpers/group'
require_relative 'optimizely/helpers/validator'
require_relative 'optimizely/helpers/variable_type'
require_relative 'optimizely/logger'
require_relative 'optimizely/notification_center'
require_relative 'optimizely/notification_center_registry'
require_relative 'optimizely/optimizely_config'
require_relative 'optimizely/optimizely_user_context'
require_relative 'optimizely/odp/lru_cache'
require_relative 'optimizely/odp/odp_manager'
require_relative 'optimizely/helpers/sdk_settings'
require_relative 'optimizely/user_profile_tracker'
require_relative 'optimizely/cmab/cmab_client'
require_relative 'optimizely/cmab/cmab_service'

module Optimizely
  class Project
    include Optimizely::Decide

    # CMAB Constants
    DEFAULT_CMAB_CACHE_TIMEOUT = (30 * 60 * 1000)
    DEFAULT_CMAB_CACHE_SIZE = 1000

    attr_reader :notification_center
    # @api no-doc
    attr_reader :config_manager, :decision_service, :error_handler, :event_dispatcher,
                :event_processor, :logger, :odp_manager, :stopped

    # Constructor for Projects.
    #
    # @param datafile - JSON string representing the project.
    # @param event_dispatcher - Provides a dispatch_event method which if given a URL and params sends a request to it.
    # @param logger - Optional component which provides a log method to log messages. By default nothing would be logged.
    # @param error_handler - Optional component which provides a handle_error method to handle exceptions.
    #                 By default all exceptions will be suppressed.
    # @param user_profile_service - Optional component which provides methods to store and retreive user profiles.
    # @param skip_json_validation - Optional boolean param to skip JSON schema validation of the provided datafile.
    # @params sdk_key - Optional string uniquely identifying the datafile corresponding to project and environment combination.
    #                   Must provide at least one of datafile or sdk_key.
    # @param config_manager - Optional Responds to 'config' method.
    # @param notification_center - Optional Instance of NotificationCenter.
    # @param event_processor - Optional Responds to process.
    # @param default_decide_options: Optional default decision options.
    # @param event_processor_options: Optional hash of options to be passed to the default batch event processor.
    # @param settings: Optional instance of OptimizelySdkSettings for sdk configuration.

    def initialize(
      datafile: nil,
      event_dispatcher: nil,
      logger: nil,
      error_handler: nil,
      skip_json_validation: false,
      user_profile_service: nil,
      sdk_key: nil,
      config_manager: nil,
      notification_center: nil,
      event_processor: nil,
      default_decide_options: [],
      event_processor_options: {},
      settings: nil
    )
      @logger = logger || NoOpLogger.new
      @error_handler = error_handler || NoOpErrorHandler.new
      @event_dispatcher = event_dispatcher || EventDispatcher.new(logger: @logger, error_handler: @error_handler)
      @user_profile_service = user_profile_service
      @default_decide_options = []
      @sdk_settings = settings

      if default_decide_options.is_a? Array
        @default_decide_options = default_decide_options.clone
      else
        @logger.log(Logger::DEBUG, 'Provided default decide options is not an array.')
        @default_decide_options = []
      end

      unless event_processor_options.is_a? Hash
        @logger.log(Logger::DEBUG, 'Provided event processor options is not a hash.')
        event_processor_options = {}
      end

      begin
        validate_instantiation_options
      rescue InvalidInputError => e
        @logger = SimpleLogger.new
        @logger.log(Logger::ERROR, e.message)
      end

      @notification_center = notification_center.is_a?(Optimizely::NotificationCenter) ? notification_center : NotificationCenter.new(@logger, @error_handler)

      @config_manager = if config_manager.respond_to?(:config) && config_manager.respond_to?(:sdk_key)
                          config_manager
                        elsif sdk_key
                          HTTPProjectConfigManager.new(
                            sdk_key: sdk_key,
                            datafile: datafile,
                            logger: @logger,
                            error_handler: @error_handler,
                            skip_json_validation: skip_json_validation,
                            notification_center: @notification_center
                          )
                        else
                          StaticProjectConfigManager.new(datafile, @logger, @error_handler, skip_json_validation)
                        end

      setup_odp!(@config_manager.sdk_key)

      # Initialize CMAB components
      @cmab_client = DefaultCmabClient.new(
        retry_config: CmabRetryConfig.new,
        logger: @logger
      )
      @cmab_cache = LRUCache.new(DEFAULT_CMAB_CACHE_SIZE, DEFAULT_CMAB_CACHE_TIMEOUT)
      @cmab_service = DefaultCmabService.new(
        @cmab_cache,
        @cmab_client,
        @logger
      )

      @decision_service = DecisionService.new(@logger, @cmab_service, @user_profile_service)

      @event_processor = if event_processor.respond_to?(:process)
                           event_processor
                         else
                           BatchEventProcessor.new(
                             event_dispatcher: @event_dispatcher,
                             logger: @logger,
                             notification_center: @notification_center,
                             batch_size: event_processor_options[:batch_size] || BatchEventProcessor::DEFAULT_BATCH_SIZE,
                             flush_interval: event_processor_options[:flush_interval] || BatchEventProcessor::DEFAULT_BATCH_INTERVAL
                           )
                         end
    end

    # Create a context of the user for which decision APIs will be called.
    #
    # A user context will be created successfully even when the SDK is not fully configured yet.
    #
    # @param user_id - The user ID to be used for bucketing.
    # @param attributes - A Hash representing user attribute names and values.
    #
    # @return [OptimizelyUserContext] An OptimizelyUserContext associated with this OptimizelyClient.
    # @return [nil] If user attributes are not in valid format.

    def create_user_context(user_id, attributes = nil)
      # We do not check for is_valid here as a user context can be created successfully
      # even when the SDK is not fully configured.

      # validate user_id
      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      # validate attributes
      return nil unless user_inputs_valid?(attributes)

      OptimizelyUserContext.new(self, user_id, attributes)
    end

    def create_optimizely_decision(user_context, flag_key, decision, reasons, decide_options, config)
      # Create Optimizely Decision Result.
      user_id = user_context.user_id
      attributes = user_context.user_attributes
      variation_key = nil
      feature_enabled = false
      rule_key = nil
      all_variables = {}
      decision_event_dispatched = false
      feature_flag = config.get_feature_flag_from_key(flag_key)
      experiment = nil
      decision_source = Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
      experiment_id = nil
      variation_id = nil

      # Send impression event if Decision came from a feature test and decide options doesn't include disableDecisionEvent
      if decision.is_a?(Optimizely::DecisionService::Decision)
        experiment = decision.experiment
        rule_key = experiment ? experiment['key'] : nil
        experiment_id = experiment ? experiment['id'] : nil
        variation = decision['variation']
        variation_key = variation ? variation['key'] : nil
        variation_id = variation ? variation['id'] : nil
        feature_enabled = variation ? variation['featureEnabled'] : false
        decision_source = decision.source
      end

      if !decide_options.include?(OptimizelyDecideOption::DISABLE_DECISION_EVENT) && (decision_source == Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST'] || config.send_flag_decisions)
        send_impression(config, experiment, variation_key || '', flag_key, rule_key || '', feature_enabled, decision_source, user_id, attributes)
        decision_event_dispatched = true
      end

      # Generate all variables map if decide options doesn't include excludeVariables
      unless decide_options.include? OptimizelyDecideOption::EXCLUDE_VARIABLES
        feature_flag['variables'].each do |variable|
          variable_value = get_feature_variable_for_variation(flag_key, feature_enabled, variation, variable, user_id)
          all_variables[variable['key']] = Helpers::VariableType.cast_value_to_type(variable_value, variable['type'], @logger)
        end
      end

      should_include_reasons = decide_options.include? OptimizelyDecideOption::INCLUDE_REASONS

      # Send notification
      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        Helpers::Constants::DECISION_NOTIFICATION_TYPES['FLAG'],
        user_id, attributes || {},
        flag_key: flag_key,
        enabled: feature_enabled,
        variables: all_variables,
        variation_key: variation_key,
        rule_key: rule_key,
        reasons: should_include_reasons ? reasons : [],
        decision_event_dispatched: decision_event_dispatched,
        experiment_id: experiment_id,
        variation_id: variation_id
      )

      OptimizelyDecision.new(
        variation_key: variation_key,
        enabled: feature_enabled,
        variables: all_variables,
        rule_key: rule_key,
        flag_key: flag_key,
        user_context: user_context,
        reasons: should_include_reasons ? reasons : []
      )
    end

    def decide(user_context, key, decide_options = [])
      # raising on user context as it is internal and not provided directly by the user.
      raise if user_context.class != OptimizelyUserContext

      reasons = []

      # check if SDK is ready
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('decide').message)
        reasons.push(OptimizelyDecisionMessage::SDK_NOT_READY)
        return OptimizelyDecision.new(flag_key: key, user_context: user_context, reasons: reasons)
      end

      # validate that key is a string
      unless key.is_a?(String)
        @logger.log(Logger::ERROR, 'Provided key is invalid')
        reasons.push(format(OptimizelyDecisionMessage::FLAG_KEY_INVALID, key))
        return OptimizelyDecision.new(flag_key: key, user_context: user_context, reasons: reasons)
      end

      # validate that key maps to a feature flag
      config = project_config
      feature_flag = config.get_feature_flag_from_key(key)
      unless feature_flag
        @logger.log(Logger::ERROR, "No feature flag was found for key '#{key}'.")
        reasons.push(format(OptimizelyDecisionMessage::FLAG_KEY_INVALID, key))
        return OptimizelyDecision.new(flag_key: key, user_context: user_context, reasons: reasons)
      end

      # merge decide_options and default_decide_options
      if decide_options.is_a? Array
        decide_options += @default_decide_options
      else
        @logger.log(Logger::DEBUG, 'Provided decide options is not an array. Using default decide options.')
        decide_options = @default_decide_options
      end

      decide_options.delete(OptimizelyDecideOption::ENABLED_FLAGS_ONLY) if decide_options.include?(OptimizelyDecideOption::ENABLED_FLAGS_ONLY)
      decide_for_keys(user_context, [key], decide_options, true)[key]
    end

    def decide_all(user_context, decide_options = [])
      # raising on user context as it is internal and not provided directly by the user.
      raise if user_context.class != OptimizelyUserContext

      # check if SDK is ready
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('decide_all').message)
        return {}
      end

      keys = []
      project_config.feature_flags.each do |feature_flag|
        keys.push(feature_flag['key'])
      end
      decide_for_keys(user_context, keys, decide_options)
    end

    def decide_for_keys(user_context, keys, decide_options = [], ignore_default_options = false) # rubocop:disable Style/OptionalBooleanParameter
      # raising on user context as it is internal and not provided directly by the user.
      raise if user_context.class != OptimizelyUserContext

      # check if SDK is ready
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('decide_for_keys').message)
        return {}
      end

      # merge decide_options and default_decide_options
      unless ignore_default_options
        if decide_options.is_a?(Array)
          decide_options += @default_decide_options
        else
          @logger.log(Logger::DEBUG, 'Provided decide options is not an array. Using default decide options.')
          decide_options = @default_decide_options
        end
      end

      # enabled_flags_only = (!decide_options.nil? && (decide_options.include? OptimizelyDecideOption::ENABLED_FLAGS_ONLY)) || (@default_decide_options.include? OptimizelyDecideOption::ENABLED_FLAGS_ONLY)

      decisions = {}
      valid_keys = []
      decision_reasons_dict = {}
      config = project_config
      return decisions unless config

      flags_without_forced_decision = []
      flag_decisions = {}

      keys.each do |key|
        # Retrieve the feature flag from the project's feature flag key map
        feature_flag = config.feature_flag_key_map[key]

        # If the feature flag is nil, create a default OptimizelyDecision and move to the next key
        if feature_flag.nil?
          decisions[key] = OptimizelyDecision.new(variation_key: nil, enabled: false, variables: nil, rule_key: nil, flag_key: key, user_context: user_context, reasons: [])
          next
        end
        valid_keys.push(key)
        decision_reasons = []
        decision_reasons_dict[key] = decision_reasons

        config = project_config
        context = Optimizely::OptimizelyUserContext::OptimizelyDecisionContext.new(key, nil)
        variation, reasons_received = @decision_service.validated_forced_decision(config, context, user_context)
        decision_reasons_dict[key].push(*reasons_received)
        if variation
          decision = Optimizely::DecisionService::Decision.new(nil, variation, Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST'])
          flag_decisions[key] = decision
        else
          flags_without_forced_decision.push(feature_flag)
        end
      end
      decision_list = @decision_service.get_variations_for_feature_list(config, flags_without_forced_decision, user_context, decide_options)

      flags_without_forced_decision.each_with_index do |flag, i|
        decision = decision_list[i].decision
        reasons = decision_list[i].reasons
        error = decision_list[i].error
        flag_key = flag['key']
        # store error decision against key and remove key from valid keys
        if error
          optimizely_decision = OptimizelyDecision.new_error_decision(flag_key, user_context, reasons)
          decisions[flag_key] = optimizely_decision
          valid_keys.delete(flag_key) if valid_keys.include?(flag_key)
          next
        end
        flag_decisions[flag_key] = decision
        decision_reasons_dict[flag_key] ||= []
        decision_reasons_dict[flag_key].push(*reasons)
      end
      valid_keys.each do |key|
        flag_decision = flag_decisions[key]
        decision_reasons = decision_reasons_dict[key]
        optimizely_decision = create_optimizely_decision(
          user_context,
          key,
          flag_decision,
          decision_reasons,
          decide_options,
          config
        )

        enabled_flags_only_missing = !decide_options.include?(OptimizelyDecideOption::ENABLED_FLAGS_ONLY)
        is_enabled = optimizely_decision.enabled

        decisions[key] = optimizely_decision if enabled_flags_only_missing || is_enabled
      end

      decisions
    end

    # Gets variation using variation key or id and flag key.
    #
    # @param flag_key - flag key from which the variation is required.
    # @param target_value - variation value either id or key that will be matched.
    # @param attribute - string representing variation attribute.
    #
    # @return [variation]
    # @return [nil] if no variation found in flag_variation_map.

    def get_flag_variation(flag_key, target_value, attribute)
      project_config.get_variation_from_flag(flag_key, target_value, attribute)
    end

    # Buckets visitor and sends impression event to Optimizely.
    #
    # @param experiment_key - Experiment which needs to be activated.
    # @param user_id - String ID for user.
    # @param attributes - Hash representing user attributes and values to be recorded.
    #
    # @return [Variation Key] representing the variation the user will be bucketed in.
    # @return [nil] if experiment is not Running, if user is not in experiment, or if datafile is invalid.

    def activate(experiment_key, user_id, attributes = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('activate').message)
        return nil
      end

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          experiment_key: experiment_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      config = project_config

      variation_key = get_variation_with_config(experiment_key, user_id, attributes, config)

      if variation_key.nil?
        @logger.log(Logger::INFO, "Not activating user '#{user_id}'.")
        return nil
      end

      # Create and dispatch impression event
      experiment = config.get_experiment_from_key(experiment_key)
      send_impression(
        config, experiment, variation_key, '', experiment_key, true,
        Optimizely::DecisionService::DECISION_SOURCES['EXPERIMENT'], user_id, attributes
      )

      variation_key
    end

    # Gets variation where visitor will be bucketed.
    #
    # @param experiment_key - Experiment for which visitor variation needs to be determined.
    # @param user_id - String ID for user.
    # @param attributes - Hash representing user attributes.
    #
    # @return [variation key] where visitor will be bucketed.
    # @return [nil] if experiment is not Running, if user is not in experiment, or if datafile is invalid.

    def get_variation(experiment_key, user_id, attributes = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_variation').message)
        return nil
      end

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          experiment_key: experiment_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      config = project_config

      get_variation_with_config(experiment_key, user_id, attributes, config)
    end

    # Force a user into a variation for a given experiment.
    #
    # @param experiment_key - String - key identifying the experiment.
    # @param user_id - String - The user ID to be used for bucketing.
    # @param variation_key - The variation key specifies the variation which the user will
    #   be forced into. If nil, then clear the existing experiment-to-variation mapping.
    #
    # @return [Boolean] indicates if the set completed successfully.

    def set_forced_variation(experiment_key, user_id, variation_key)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('set_forced_variation').message)
        return nil
      end

      input_values = {experiment_key: experiment_key, user_id: user_id}
      input_values[:variation_key] = variation_key unless variation_key.nil?
      return false unless Optimizely::Helpers::Validator.inputs_valid?(input_values, @logger, Logger::ERROR)

      config = project_config

      @decision_service.set_forced_variation(config, experiment_key, user_id, variation_key)
    end

    # Gets the forced variation for a given user and experiment.
    #
    # @param experiment_key - String - Key identifying the experiment.
    # @param user_id - String - The user ID to be used for bucketing.
    #
    # @return [String] The forced variation key.

    def get_forced_variation(experiment_key, user_id)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_forced_variation').message)
        return nil
      end

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          experiment_key: experiment_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      config = project_config

      forced_variation_key = nil
      forced_variation, = @decision_service.get_forced_variation(config, experiment_key, user_id)
      forced_variation_key = forced_variation['key'] if forced_variation

      forced_variation_key
    end

    # Send conversion event to Optimizely.
    #
    # @param event_key - Event key representing the event which needs to be recorded.
    # @param user_id - String ID for user.
    # @param attributes - Hash representing visitor attributes and values which need to be recorded.
    # @param event_tags - Hash representing metadata associated with the event.

    def track(event_key, user_id, attributes = nil, event_tags = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('track').message)
        return nil
      end

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          event_key: event_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      return nil unless user_inputs_valid?(attributes, event_tags)

      config = project_config

      event = config.get_event_from_key(event_key)
      unless event
        @logger.log(Logger::INFO, "Not tracking user '#{user_id}' for event '#{event_key}'.")
        return nil
      end

      user_event = UserEventFactory.create_conversion_event(config, event, user_id, attributes, event_tags)
      @event_processor.process(user_event)
      @logger.log(Logger::INFO, "Tracking event '#{event_key}' for user '#{user_id}'.")

      if @notification_center.notification_count(NotificationCenter::NOTIFICATION_TYPES[:TRACK]).positive?
        log_event = EventFactory.create_log_event(user_event, @logger)
        @notification_center.send_notifications(
          NotificationCenter::NOTIFICATION_TYPES[:TRACK],
          event_key, user_id, attributes, event_tags, log_event
        )
      end
      nil
    end

    # Determine whether a feature is enabled.
    # Sends an impression event if the user is bucketed into an experiment using the feature.
    #
    # @param feature_flag_key - String unique key of the feature.
    # @param user_id - String ID of the user.
    # @param attributes - Hash representing visitor attributes and values which need to be recorded.
    #
    # @return [True] if the feature is enabled.
    # @return [False] if the feature is disabled.
    # @return [False] if the feature is not found.

    def is_feature_enabled(feature_flag_key, user_id, attributes = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('is_feature_enabled').message)
        return false
      end

      return false unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          feature_flag_key: feature_flag_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      return false unless user_inputs_valid?(attributes)

      config = project_config

      feature_flag = config.get_feature_flag_from_key(feature_flag_key)
      unless feature_flag
        @logger.log(Logger::ERROR, "No feature flag was found for key '#{feature_flag_key}'.")
        return false
      end

      user_context = OptimizelyUserContext.new(self, user_id, attributes, identify: false)
      decision_result = @decision_service.get_variation_for_feature(config, feature_flag, user_context)
      decision = decision_result.decision
      feature_enabled = false
      source_string = Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
      if decision.is_a?(Optimizely::DecisionService::Decision)
        variation = decision['variation']
        feature_enabled = variation['featureEnabled']
        if decision.source == Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          source_string = Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          source_info = {
            experiment_key: decision.experiment['key'],
            variation_key: variation['key']
          }
          # Send event if Decision came from a feature test.
          send_impression(
            config, decision.experiment, variation['key'], feature_flag_key, decision.experiment['key'], feature_enabled, source_string, user_id, attributes
          )
        elsif decision.source == Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT'] && config.send_flag_decisions
          send_impression(
            config, decision.experiment, variation['key'], feature_flag_key, decision.experiment['key'], feature_enabled, source_string, user_id, attributes
          )
        end
      end

      if decision.nil? && config.send_flag_decisions
        send_impression(
          config, nil, '', feature_flag_key, '', feature_enabled, source_string, user_id, attributes
        )
      end

      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        Helpers::Constants::DECISION_NOTIFICATION_TYPES['FEATURE'],
        user_id, attributes || {},
        feature_key: feature_flag_key,
        feature_enabled: feature_enabled,
        source: source_string,
        source_info: source_info || {}
      )

      if feature_enabled == true
        @logger.log(Logger::INFO,
                    "Feature '#{feature_flag_key}' is enabled for user '#{user_id}'.")
        return true
      end

      @logger.log(Logger::INFO,
                  "Feature '#{feature_flag_key}' is not enabled for user '#{user_id}'.")
      false
    end

    # Gets keys of all feature flags which are enabled for the user.
    #
    # @param user_id -  ID for user.
    # @param attributes - Dict representing user attributes.
    # @return [feature flag keys] A List of feature flag keys that are enabled for the user.

    def get_enabled_features(user_id, attributes = nil)
      enabled_features = []
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_enabled_features').message)
        return enabled_features
      end

      return enabled_features unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      return enabled_features unless user_inputs_valid?(attributes)

      config = project_config

      config.feature_flags.each do |feature|
        enabled_features.push(feature['key']) if is_feature_enabled(
          feature['key'],
          user_id,
          attributes
        ) == true
      end
      enabled_features
    end

    # Get the value of the specified variable in the feature flag.
    #
    # @param feature_flag_key - String key of feature flag the variable belongs to
    # @param variable_key - String key of variable for which we are getting the value
    # @param user_id - String user ID
    # @param attributes - Hash representing visitor attributes and values which need to be recorded.
    #
    # @return [*] the type-casted variable value.
    # @return [nil] if the feature flag or variable are not found.

    def get_feature_variable(feature_flag_key, variable_key, user_id, attributes = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_feature_variable').message)
        return nil
      end
      get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        nil,
        user_id,
        attributes
      )
    end

    # Get the String value of the specified variable in the feature flag.
    #
    # @param feature_flag_key - String key of feature flag the variable belongs to
    # @param variable_key - String key of variable for which we are getting the string value
    # @param user_id - String user ID
    # @param attributes - Hash representing visitor attributes and values which need to be recorded.
    #
    # @return [String] the string variable value.
    # @return [nil] if the feature flag or variable are not found.

    def get_feature_variable_string(feature_flag_key, variable_key, user_id, attributes = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_feature_variable_string').message)
        return nil
      end
      get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['STRING'],
        user_id,
        attributes
      )
    end

    # Get the Json value of the specified variable in the feature flag in a Dict.
    #
    # @param feature_flag_key - String key of feature flag the variable belongs to
    # @param variable_key - String key of variable for which we are getting the string value
    # @param user_id - String user ID
    # @param attributes - Hash representing visitor attributes and values which need to be recorded.
    #
    # @return [Dict] the Dict containing variable value.
    # @return [nil] if the feature flag or variable are not found.

    def get_feature_variable_json(feature_flag_key, variable_key, user_id, attributes = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_feature_variable_json').message)
        return nil
      end
      get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['JSON'],
        user_id,
        attributes
      )
    end

    # Get the Boolean value of the specified variable in the feature flag.
    #
    # @param feature_flag_key - String key of feature flag the variable belongs to
    # @param variable_key - String key of variable for which we are getting the string value
    # @param user_id - String user ID
    # @param attributes - Hash representing visitor attributes and values which need to be recorded.
    #
    # @return [Boolean] the boolean variable value.
    # @return [nil] if the feature flag or variable are not found.

    def get_feature_variable_boolean(feature_flag_key, variable_key, user_id, attributes = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_feature_variable_boolean').message)
        return nil
      end

      get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['BOOLEAN'],
        user_id,
        attributes
      )
    end

    # Get the Double value of the specified variable in the feature flag.
    #
    # @param feature_flag_key - String key of feature flag the variable belongs to
    # @param variable_key - String key of variable for which we are getting the string value
    # @param user_id - String user ID
    # @param attributes - Hash representing visitor attributes and values which need to be recorded.
    #
    # @return [Boolean] the double variable value.
    # @return [nil] if the feature flag or variable are not found.

    def get_feature_variable_double(feature_flag_key, variable_key, user_id, attributes = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_feature_variable_double').message)
        return nil
      end

      get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['DOUBLE'],
        user_id,
        attributes
      )
    end

    # Get values of all the variables in the feature flag and returns them in a Dict
    #
    # @param feature_flag_key - String key of feature flag
    # @param user_id - String user ID
    # @param attributes - Hash representing visitor attributes and values which need to be recorded.
    #
    # @return [Dict] the Dict containing all the varible values
    # @return [nil] if the feature flag is not found.

    def get_all_feature_variables(feature_flag_key, user_id, attributes = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_all_feature_variables').message)
        return nil
      end

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          feature_flag_key: feature_flag_key,
          user_id: user_id
        },
        @logger, Logger::ERROR
      )

      return nil unless user_inputs_valid?(attributes)

      config = project_config

      feature_flag = config.get_feature_flag_from_key(feature_flag_key)
      unless feature_flag
        @logger.log(Logger::INFO, "No feature flag was found for key '#{feature_flag_key}'.")
        return nil
      end

      user_context = OptimizelyUserContext.new(self, user_id, attributes, identify: false)
      decision_result = @decision_service.get_variation_for_feature(config, feature_flag, user_context)
      decision = decision_result.decision
      variation = decision ? decision['variation'] : nil
      feature_enabled = variation ? variation['featureEnabled'] : false
      all_variables = {}

      feature_flag['variables'].each do |variable|
        variable_value = get_feature_variable_for_variation(feature_flag_key, feature_enabled, variation, variable, user_id)
        all_variables[variable['key']] = Helpers::VariableType.cast_value_to_type(variable_value, variable['type'], @logger)
      end

      source_string = Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
      if decision && decision['source'] == Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        source_info = {
          experiment_key: decision.experiment['key'],
          variation_key: variation['key']
        }
        source_string = Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
      end

      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        Helpers::Constants::DECISION_NOTIFICATION_TYPES['ALL_FEATURE_VARIABLES'], user_id, attributes || {},
        feature_key: feature_flag_key,
        feature_enabled: feature_enabled,
        source: source_string,
        variable_values: all_variables,
        source_info: source_info || {}
      )

      all_variables
    end

    # Get the Integer value of the specified variable in the feature flag.
    #
    # @param feature_flag_key - String key of feature flag the variable belongs to
    # @param variable_key - String key of variable for which we are getting the string value
    # @param user_id - String user ID
    # @param attributes - Hash representing visitor attributes and values which need to be recorded.
    #
    # @return [Integer] variable value.
    # @return [nil] if the feature flag or variable are not found.

    def get_feature_variable_integer(feature_flag_key, variable_key, user_id, attributes = nil)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_feature_variable_integer').message)
        return nil
      end

      get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['INTEGER'],
        user_id,
        attributes
      )
    end

    def is_valid
      config = project_config
      config.is_a?(Optimizely::ProjectConfig)
    end

    def close
      return if @stopped

      @stopped = true
      @config_manager.stop! if @config_manager.respond_to?(:stop!)
      @event_processor.stop! if @event_processor.respond_to?(:stop!)
      @odp_manager.stop!
    end

    def get_optimizely_config
      # Get OptimizelyConfig object containing experiments and features data
      # Returns Object
      #
      # OptimizelyConfig Object Schema
      # {
      #   'experimentsMap' => {
      #     'my-fist-experiment' => {
      #       'id' => '111111',
      #       'key' => 'my-fist-experiment'
      #       'variationsMap' => {
      #         'variation_1' => {
      #           'id' => '121212',
      #           'key' => 'variation_1',
      #           'variablesMap' => {
      #             'age' => {
      #               'id' => '222222',
      #               'key' => 'age',
      #               'type' => 'integer',
      #               'value' => '0',
      #             }
      #           }
      #         }
      #       }
      #     }
      #   },
      #   'featuresMap' => {
      #     'awesome-feature' => {
      #       'id' => '333333',
      #       'key' => 'awesome-feature',
      #       'experimentsMap' => Object,
      #       'variablesMap' => Object,
      #     }
      #   },
      #   'revision' => '13',
      # }
      #
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('get_optimizely_config').message)
        return nil
      end

      # config_manager might not contain optimizely_config if its supplied by the consumer
      # Generating a new OptimizelyConfig object in this case as a fallback
      if @config_manager.respond_to?(:optimizely_config)
        @config_manager.optimizely_config
      else
        OptimizelyConfig.new(project_config, @logger).config
      end
    end

    # Send an event to the ODP server.
    #
    # @param action - the event action name. Cannot be nil or empty string.
    # @param identifiers - a hash for identifiers. The caller must provide at least one key-value pair.
    # @param type - the event type (default = "fullstack").
    # @param data - a hash for associated data. The default event data will be added to this data before sending to the ODP server.

    def send_odp_event(action:, identifiers:, type: Helpers::Constants::ODP_MANAGER_CONFIG[:EVENT_TYPE], data: {})
      unless identifiers.is_a?(Hash) && !identifiers.empty?
        @logger.log(Logger::ERROR, 'ODP events must have at least one key-value pair in identifiers.')
        return
      end

      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('send_odp_event').message)
        return
      end

      if action.nil? || action.empty?
        @logger.log(Logger::ERROR, Helpers::Constants::ODP_LOGS[:ODP_INVALID_ACTION])
        return
      end

      type = Helpers::Constants::ODP_MANAGER_CONFIG[:EVENT_TYPE] if type.nil? || type.empty?

      @odp_manager.send_event(type: type, action: action, identifiers: identifiers, data: data)
    end

    def identify_user(user_id:)
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('identify_user').message)
        return
      end

      @odp_manager.identify_user(user_id: user_id)
    end

    def fetch_qualified_segments(user_id:, options: [])
      unless is_valid
        @logger.log(Logger::ERROR, InvalidProjectConfigError.new('fetch_qualified_segments').message)
        return
      end

      @odp_manager.fetch_qualified_segments(user_id: user_id, options: options)
    end

    private

    def get_variation_with_config(experiment_key, user_id, attributes, config)
      # Gets variation where visitor will be bucketed.
      #
      # experiment_key - Experiment for which visitor variation needs to be determined.
      # user_id - String ID for user.
      # attributes - Hash representing user attributes.
      # config - Instance of DatfileProjectConfig
      #
      # Returns [variation key] where visitor will be bucketed.
      # Returns [nil] if experiment is not Running, if user is not in experiment, or if datafile is invalid.
      experiment = config.get_experiment_from_key(experiment_key)
      return nil if experiment.nil?

      experiment_id = experiment['id']

      return nil unless user_inputs_valid?(attributes)

      user_context = OptimizelyUserContext.new(self, user_id, attributes, identify: false)
      user_profile_tracker = UserProfileTracker.new(user_id, @user_profile_service, @logger)
      user_profile_tracker.load_user_profile
      variation_result = @decision_service.get_variation(config, experiment_id, user_context, user_profile_tracker)
      variation_id = variation_result.variation_id
      user_profile_tracker.save_user_profile
      variation = config.get_variation_from_id(experiment_key, variation_id) unless variation_id.nil?
      variation_key = variation['key'] if variation
      decision_notification_type = if config.feature_experiment?(experiment_id)
                                     Helpers::Constants::DECISION_NOTIFICATION_TYPES['FEATURE_TEST']
                                   else
                                     Helpers::Constants::DECISION_NOTIFICATION_TYPES['AB_TEST']
                                   end
      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        decision_notification_type, user_id, attributes || {},
        experiment_key: experiment_key,
        variation_key: variation_key
      )

      variation_key
    end

    def get_feature_variable_for_type(feature_flag_key, variable_key, variable_type, user_id, attributes = nil)
      # Get the variable value for the given feature variable and cast it to the specified type
      # The default value is returned if the feature flag is not enabled for the user.
      #
      # feature_flag_key - String key of feature flag the variable belongs to
      # variable_key - String key of variable for which we are getting the string value
      # variable_type - String requested type for feature variable
      # user_id - String user ID
      # attributes - Hash representing visitor attributes and values which need to be recorded.
      #
      # Returns the type-casted variable value.
      # Returns nil if the feature flag or variable or user ID is empty
      #             in case of variable type mismatch

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          feature_flag_key: feature_flag_key,
          variable_key: variable_key,
          user_id: user_id,
          variable_type: variable_type
        },
        @logger, Logger::ERROR
      )

      return nil unless user_inputs_valid?(attributes)

      config = project_config

      feature_flag = config.get_feature_flag_from_key(feature_flag_key)
      unless feature_flag
        @logger.log(Logger::INFO, "No feature flag was found for key '#{feature_flag_key}'.")
        return nil
      end

      variable = config.get_feature_variable(feature_flag, variable_key)

      # Error message logged in DatafileProjectConfig- get_feature_flag_from_key
      return nil if variable.nil?

      # If variable_type is nil, set it equal to variable['type']
      variable_type ||= variable['type']
      # Returns nil if type differs
      if variable['type'] != variable_type
        @logger.log(Logger::WARN,
                    "Requested variable as type '#{variable_type}' but variable '#{variable_key}' is of type '#{variable['type']}'.")
        return nil
      end

      user_context = OptimizelyUserContext.new(self, user_id, attributes, identify: false)
      decision_result = @decision_service.get_variation_for_feature(config, feature_flag, user_context)
      decision = decision_result.decision
      variation = decision ? decision['variation'] : nil
      feature_enabled = variation ? variation['featureEnabled'] : false

      variable_value = get_feature_variable_for_variation(feature_flag_key, feature_enabled, variation, variable, user_id)
      variable_value = Helpers::VariableType.cast_value_to_type(variable_value, variable_type, @logger)

      source_string = Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
      if decision && decision['source'] == Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        source_info = {
          experiment_key: decision.experiment['key'],
          variation_key: variation['key']
        }
        source_string = Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
      end

      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        Helpers::Constants::DECISION_NOTIFICATION_TYPES['FEATURE_VARIABLE'], user_id, attributes || {},
        feature_key: feature_flag_key,
        feature_enabled: feature_enabled,
        source: source_string,
        variable_key: variable_key,
        variable_type: variable_type,
        variable_value: variable_value,
        source_info: source_info || {}
      )

      variable_value
    end

    def get_feature_variable_for_variation(feature_flag_key, feature_enabled, variation, variable, user_id)
      # Helper method to get the non type-casted value for a variable attached to a
      # feature flag. Returns appropriate variable value depending on whether there
      # was a matching variation, feature was enabled or not or varible was part of the
      # available variation or not. Also logs the appropriate message explaining how it
      # evaluated the value of the variable.
      #
      # feature_flag_key - String key of feature flag the variable belongs to
      # feature_enabled - Boolean indicating if feature is enabled or not
      # variation - varition returned by decision service
      # user_id - String user ID
      #
      # Returns string value of the variable.

      config = project_config
      variable_value = variable['defaultValue']
      if variation
        if feature_enabled == true
          variation_variable_usages = config.variation_id_to_variable_usage_map[variation['id']]
          variable_id = variable['id']
          if variation_variable_usages&.key?(variable_id)
            variable_value = variation_variable_usages[variable_id]['value']
            @logger.log(Logger::INFO,
                        "Got variable value '#{variable_value}' for variable '#{variable['key']}' of feature flag '#{feature_flag_key}'.")
          else
            @logger.log(Logger::DEBUG,
                        "Variable value is not defined. Returning the default variable value '#{variable_value}' for variable '#{variable['key']}'.")

          end
        else
          @logger.log(Logger::DEBUG,
                      "Feature '#{feature_flag_key}' is not enabled for user '#{user_id}'. Returning the default variable value '#{variable_value}'.")
        end
      else
        @logger.log(Logger::INFO,
                    "User '#{user_id}' was not bucketed into experiment or rollout for feature flag '#{feature_flag_key}'. Returning the default variable value '#{variable_value}'.")
      end
      variable_value
    end

    def user_inputs_valid?(attributes = nil, event_tags = nil)
      # Helper method to validate user inputs.
      #
      # attributes - Dict representing user attributes.
      # event_tags - Dict representing metadata associated with an event.
      #
      # Returns boolean True if inputs are valid. False otherwise.

      return false if !attributes.nil? && !attributes_valid?(attributes)

      return false if !event_tags.nil? && !event_tags_valid?(event_tags)

      true
    end

    def attributes_valid?(attributes)
      unless Helpers::Validator.attributes_valid?(attributes)
        @logger.log(Logger::ERROR, 'Provided attributes are in an invalid format.')
        @error_handler.handle_error(InvalidAttributeFormatError)
        return false
      end
      true
    end

    def event_tags_valid?(event_tags)
      unless Helpers::Validator.event_tags_valid?(event_tags)
        @logger.log(Logger::ERROR, 'Provided event tags are in an invalid format.')
        @error_handler.handle_error(InvalidEventTagFormatError)
        return false
      end
      true
    end

    def validate_instantiation_options
      raise InvalidInputError, 'logger' unless Helpers::Validator.logger_valid?(@logger)

      unless Helpers::Validator.error_handler_valid?(@error_handler)
        @error_handler = NoOpErrorHandler.new
        raise InvalidInputError, 'error_handler'
      end

      return if Helpers::Validator.event_dispatcher_valid?(@event_dispatcher)

      @event_dispatcher = EventDispatcher.new(logger: @logger, error_handler: @error_handler)
      raise InvalidInputError, 'event_dispatcher'
    end

    def send_impression(config, experiment, variation_key, flag_key, rule_key, enabled, rule_type, user_id, attributes = nil)
      if experiment.nil?
        experiment = {
          'id' => '',
          'key' => '',
          'layerId' => '',
          'status' => '',
          'variations' => [],
          'trafficAllocation' => [],
          'audienceIds' => [],
          'audienceConditions' => [],
          'forcedVariations' => {}
        }
      end

      experiment_id = experiment['id']
      experiment_key = experiment['key']

      variation_id = config.get_variation_id_from_key_by_experiment_id(experiment_id, variation_key) unless experiment_id.empty?

      unless variation_id
        variation = !flag_key.empty? ? get_flag_variation(flag_key, variation_key, 'key') : nil
        variation_id = variation ? variation['id'] : ''
      end

      metadata = {
        flag_key: flag_key,
        rule_key: rule_key,
        rule_type: rule_type,
        variation_key: variation_key,
        enabled: enabled
      }

      user_event = UserEventFactory.create_impression_event(config, experiment, variation_id, metadata, user_id, attributes)
      @event_processor.process(user_event)
      return unless @notification_center.notification_count(NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]).positive?

      @logger.log(Logger::INFO, "Activating user '#{user_id}' in experiment '#{experiment_key}'.")

      experiment = nil if experiment_id == ''
      variation = nil
      variation = config.get_variation_from_id_by_experiment_id(experiment_id, variation_id) unless experiment.nil?
      log_event = EventFactory.create_log_event(user_event, @logger)
      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
        experiment, user_id, attributes, variation, log_event
      )
    end

    def project_config
      @config_manager.config
    end

    def update_odp_config_on_datafile_update
      # if datafile isn't ready, expects to be called again by the internal notification_center
      return if @config_manager.respond_to?(:ready?) && !@config_manager.ready?

      config = @config_manager&.config
      return unless config

      @odp_manager.update_odp_config(config.public_key_for_odp, config.host_for_odp, config.all_segments)
    end

    def setup_odp!(sdk_key)
      unless @sdk_settings.is_a? Optimizely::Helpers::OptimizelySdkSettings
        @logger.log(Logger::DEBUG, 'Provided sdk_settings is not an OptimizelySdkSettings instance.') unless @sdk_settings.nil?
        @sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new
      end

      if !@sdk_settings.odp_segment_manager.nil? && !Helpers::Validator.segment_manager_valid?(@sdk_settings.odp_segment_manager)
        @logger.log(Logger::ERROR, 'Invalid ODP segment manager, reverting to default.')
        @sdk_settings.odp_segment_manager = nil
      end

      if !@sdk_settings.odp_event_manager.nil? && !Helpers::Validator.event_manager_valid?(@sdk_settings.odp_event_manager)
        @logger.log(Logger::ERROR, 'Invalid ODP event manager, reverting to default.')
        @sdk_settings.odp_event_manager = nil
      end

      if !@sdk_settings.odp_segments_cache.nil? && !Helpers::Validator.segments_cache_valid?(@sdk_settings.odp_segments_cache)
        @logger.log(Logger::ERROR, 'Invalid ODP segments cache, reverting to default.')
        @sdk_settings.odp_segments_cache = nil
      end

      # no need to instantiate a cache if a custom cache or segment manager is provided.
      if !@sdk_settings.odp_disabled && @sdk_settings.odp_segment_manager.nil?
        @sdk_settings.odp_segments_cache ||= LRUCache.new(
          @sdk_settings.segments_cache_size,
          @sdk_settings.segments_cache_timeout_in_secs
        )
      end

      @odp_manager = OdpManager.new(
        disable: @sdk_settings.odp_disabled,
        segment_manager: @sdk_settings.odp_segment_manager,
        event_manager: @sdk_settings.odp_event_manager,
        segments_cache: @sdk_settings.odp_segments_cache,
        fetch_segments_timeout: @sdk_settings.fetch_segments_timeout,
        odp_event_timeout: @sdk_settings.odp_event_timeout,
        odp_flush_interval: @sdk_settings.odp_flush_interval,
        logger: @logger
      )

      return if @sdk_settings.odp_disabled

      Optimizely::NotificationCenterRegistry
        .get_notification_center(sdk_key, @logger)
        &.add_notification_listener(
          NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE],
          method(:update_odp_config_on_datafile_update)
        )

      update_odp_config_on_datafile_update
    end
  end
end
