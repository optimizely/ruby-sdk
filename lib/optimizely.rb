# frozen_string_literal: true

#
#    Copyright 2016-2020, Optimizely and contributors
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
require_relative 'optimizely/decision_service'
require_relative 'optimizely/error_handler'
require_relative 'optimizely/event_builder'
require_relative 'optimizely/event/forwarding_event_processor'
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
require_relative 'optimizely/optimizely_config'

module Optimizely
  class Project
    attr_reader :notification_center
    # @api no-doc
    attr_reader :config_manager, :decision_service, :error_handler, :event_dispatcher,
                :event_processor, :logger, :stopped

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

    def initialize(
      datafile = nil,
      event_dispatcher = nil,
      logger = nil,
      error_handler = nil,
      skip_json_validation = false,
      user_profile_service = nil,
      sdk_key = nil,
      config_manager = nil,
      notification_center = nil,
      event_processor = nil
    )
      @logger = logger || NoOpLogger.new
      @error_handler = error_handler || NoOpErrorHandler.new
      @event_dispatcher = event_dispatcher || EventDispatcher.new(logger: @logger, error_handler: @error_handler)
      @user_profile_service = user_profile_service

      begin
        validate_instantiation_options
      rescue InvalidInputError => e
        @logger = SimpleLogger.new
        @logger.log(Logger::ERROR, e.message)
      end

      @notification_center = notification_center.is_a?(Optimizely::NotificationCenter) ? notification_center : NotificationCenter.new(@logger, @error_handler)

      @config_manager = if config_manager.respond_to?(:config)
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

      @decision_service = DecisionService.new(@logger, @user_profile_service)

      @event_processor = if event_processor.respond_to?(:process)
                           event_processor
                         else
                           ForwardingEventProcessor.new(@event_dispatcher, @logger, @notification_center)
                         end
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
      send_impression(config, experiment, variation_key, user_id, attributes)

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
      forced_variation = @decision_service.get_forced_variation(config, experiment_key, user_id)
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

      decision = @decision_service.get_variation_for_feature(config, feature_flag, user_id, attributes)

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
          # Send event if Decision came from an experiment.
          send_impression(config, decision.experiment, variation['key'], user_id, attributes)
        else
          @logger.log(Logger::DEBUG,
                      "The user '#{user_id}' is not being experimented on in feature '#{feature_flag_key}'.")
        end
      end

      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        Helpers::Constants::DECISION_NOTIFICATION_TYPES['FEATURE'],
        user_id, (attributes || {}),
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
      variable_value = get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        nil,
        user_id,
        attributes
      )

      variable_value
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
      variable_value = get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['STRING'],
        user_id,
        attributes
      )

      variable_value
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
      variable_value = get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['JSON'],
        user_id,
        attributes
      )

      variable_value
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

      variable_value = get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['BOOLEAN'],
        user_id,
        attributes
      )

      variable_value
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

      variable_value = get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['DOUBLE'],
        user_id,
        attributes
      )

      variable_value
    end

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

      decision = @decision_service.get_variation_for_feature(config, feature_flag, user_id, attributes)
      variation = decision ? decision['variation'] : nil
      feature_enabled = variation ? variation['featureEnabled'] : false
      all_variables = {}

      feature_flag['variables'].each do |variable|
        variable_value = get_feature_variable_for_variation(feature_flag_key, feature_enabled, variation, variable, user_id)
        variable_value = Helpers::VariableType.cast_value_to_type(variable_value, variable['type'], @logger)
        all_variables[variable['key']] = variable_value
      end

      source_string = Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
      if decision && decision['source'] == Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        source_info = {
          experiment_key: decision.experiment['key'],
          variation_key: variation['key']
        }
        source_string = Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
      end

      #       @notification_center.send_notifications(
      #         NotificationCenter::NOTIFICATION_TYPES[:DECISION],
      #         Helpers::Constants::DECISION_NOTIFICATION_TYPES['FEATURE_VARIABLE'], user_id, (attributes || {}),
      #         feature_key: feature_flag_key,
      #         feature_enabled: feature_enabled,
      #         source: source_string,
      #         variable_key: variable_key,
      #         variable_type: variable_type,
      #         variable_value: variable_value,
      #         source_info: source_info || {}
      #       )
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

      variable_value = get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['INTEGER'],
        user_id,
        attributes
      )

      variable_value
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
        OptimizelyConfig.new(project_config).config
      end
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

      return nil unless user_inputs_valid?(attributes)

      variation_id = @decision_service.get_variation(config, experiment_key, user_id, attributes)
      variation = config.get_variation_from_id(experiment_key, variation_id) unless variation_id.nil?
      variation_key = variation['key'] if variation
      decision_notification_type = if config.feature_experiment?(experiment['id'])
                                     Helpers::Constants::DECISION_NOTIFICATION_TYPES['FEATURE_TEST']
                                   else
                                     Helpers::Constants::DECISION_NOTIFICATION_TYPES['AB_TEST']
                                   end
      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        decision_notification_type, user_id, (attributes || {}),
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

      decision = @decision_service.get_variation_for_feature(config, feature_flag, user_id, attributes)
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
        Helpers::Constants::DECISION_NOTIFICATION_TYPES['FEATURE_VARIABLE'], user_id, (attributes || {}),
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
                        "Variable '#{variable['key']}' is not used in variation '#{variation['key']}'. Returning the default variable value '#{variable_value}'.")
          end
        else
          @logger.log(Logger::DEBUG,
                      "Feature '#{feature_flag_key}' for variation '#{variation['key']}' is not enabled. Returning the default variable value '#{variable_value}'.")
        end
      else
        @logger.log(Logger::INFO,
                    "User '#{user_id}' was not bucketed into any variation for feature flag '#{feature_flag_key}'. Returning the default variable value '#{variable_value}'.")
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

    def send_impression(config, experiment, variation_key, user_id, attributes = nil)
      experiment_key = experiment['key']
      variation_id = config.get_variation_id_from_key(experiment_key, variation_key)
      user_event = UserEventFactory.create_impression_event(config, experiment, variation_id, user_id, attributes)
      @event_processor.process(user_event)
      return unless @notification_center.notification_count(NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]).positive?

      @logger.log(Logger::INFO, "Activating user '#{user_id}' in experiment '#{experiment_key}'.")
      variation = config.get_variation_from_id(experiment_key, variation_id)
      log_event = EventFactory.create_log_event(user_event, @logger)
      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
        experiment, user_id, attributes, variation, log_event
      )
    end

    def project_config
      @config_manager.config
    end
  end
end
