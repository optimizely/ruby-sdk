# frozen_string_literal: true

#
#    Copyright 2016-2019, Optimizely and contributors
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
require_relative 'optimizely/decision_service'
require_relative 'optimizely/error_handler'
require_relative 'optimizely/event_builder'
require_relative 'optimizely/event_dispatcher'
require_relative 'optimizely/exceptions'
require_relative 'optimizely/helpers/constants'
require_relative 'optimizely/helpers/group'
require_relative 'optimizely/helpers/validator'
require_relative 'optimizely/helpers/variable_type'
require_relative 'optimizely/logger'
require_relative 'optimizely/notification_center'
require_relative 'optimizely/project_config'

module Optimizely
  class Project
    attr_reader :notification_center
    # @api no-doc
    attr_reader :is_valid, :config, :decision_service, :error_handler,
                :event_builder, :event_dispatcher, :logger

    # Constructor for Projects.
    #
    # @param datafile - JSON string representing the project.
    # @param event_dispatcher - Provides a dispatch_event method which if given a URL and params sends a request to it.
    # @param logger - Optional component which provides a log method to log messages. By default nothing would be logged.
    # @param error_handler - Optional component which provides a handle_error method to handle exceptions.
    #                 By default all exceptions will be suppressed.
    # @param user_profile_service - Optional component which provides methods to store and retreive user profiles.
    # @param skip_json_validation - Optional boolean param to skip JSON schema validation of the provided datafile.

    def initialize(datafile, event_dispatcher = nil, logger = nil, error_handler = nil, skip_json_validation = false, user_profile_service = nil)
      @is_valid = true
      @logger = logger || NoOpLogger.new
      @error_handler = error_handler || NoOpErrorHandler.new
      @event_dispatcher = event_dispatcher || EventDispatcher.new
      @user_profile_service = user_profile_service

      begin
        validate_instantiation_options(datafile, skip_json_validation)
      rescue InvalidInputError => e
        @is_valid = false
        @logger = SimpleLogger.new
        @logger.log(Logger::ERROR, e.message)
        return
      end

      begin
        @config = ProjectConfig.new(datafile, @logger, @error_handler)
      rescue StandardError => e
        @is_valid = false
        @logger = SimpleLogger.new
        error_msg = e.class == InvalidDatafileVersionError ? e.message : InvalidInputError.new('datafile').message
        error_to_handle = e.class == InvalidDatafileVersionError ? InvalidDatafileVersionError : InvalidInputError
        @logger.log(Logger::ERROR, error_msg)
        @error_handler.handle_error error_to_handle
        return
      end

      @decision_service = DecisionService.new(@config, @user_profile_service)
      @event_builder = EventBuilder.new(@config, @logger)
      @notification_center = NotificationCenter.new(@logger, @error_handler)
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
      unless @is_valid
        @logger.log(Logger::ERROR, InvalidDatafileError.new('activate').message)
        return nil
      end

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          experiment_key: experiment_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      variation_key = get_variation(experiment_key, user_id, attributes)

      if variation_key.nil?
        @logger.log(Logger::INFO, "Not activating user '#{user_id}'.")
        return nil
      end

      # Create and dispatch impression event
      experiment = @config.get_experiment_from_key(experiment_key)
      send_impression(experiment, variation_key, user_id, attributes)

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
      unless @is_valid
        @logger.log(Logger::ERROR, InvalidDatafileError.new('get_variation').message)
        return nil
      end

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          experiment_key: experiment_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      unless user_inputs_valid?(attributes)
        @logger.log(Logger::INFO, "Not activating user '#{user_id}.")
        return nil
      end

      variation_id = @decision_service.get_variation(experiment_key, user_id, attributes)

      unless variation_id.nil?
        variation = @config.get_variation_from_id(experiment_key, variation_id)
        return variation['key'] if variation
      end
      nil
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
      @config.set_forced_variation(experiment_key, user_id, variation_key)
    end

    # Gets the forced variation for a given user and experiment.
    #
    # @param experiment_key - String - Key identifying the experiment.
    # @param user_id - String - The user ID to be used for bucketing.
    #
    # @return [String] The forced variation key.

    def get_forced_variation(experiment_key, user_id)
      forced_variation_key = nil
      forced_variation = @config.get_forced_variation(experiment_key, user_id)
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
      unless @is_valid
        @logger.log(Logger::ERROR, InvalidDatafileError.new('track').message)
        return nil
      end

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          event_key: event_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      return nil unless user_inputs_valid?(attributes, event_tags)

      event = @config.get_event_from_key(event_key)
      unless event
        @config.logger.log(Logger::INFO, "Not tracking user '#{user_id}' for event '#{event_key}'.")
        return nil
      end

      conversion_event = @event_builder.create_conversion_event(event, user_id, attributes, event_tags)
      @config.logger.log(Logger::INFO, "Tracking event '#{event_key}' for user '#{user_id}'.")
      @logger.log(Logger::INFO,
                  "Dispatching conversion event to URL #{conversion_event.url} with params #{conversion_event.params}.")
      begin
        @event_dispatcher.dispatch_event(conversion_event)
      rescue => e
        @logger.log(Logger::ERROR, "Unable to dispatch conversion event. Error: #{e}")
      end

      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:TRACK],
        event_key, user_id, attributes, event_tags, conversion_event
      )
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
      unless @is_valid
        @logger.log(Logger::ERROR, InvalidDatafileError.new('is_feature_enabled').message)
        return false
      end

      return false unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          feature_flag_key: feature_flag_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      return false unless user_inputs_valid?(attributes)

      feature_flag = @config.get_feature_flag_from_key(feature_flag_key)
      unless feature_flag
        @logger.log(Logger::ERROR, "No feature flag was found for key '#{feature_flag_key}'.")
        return false
      end

      decision = @decision_service.get_variation_for_feature(feature_flag, user_id, attributes)
      if decision.nil?
        @logger.log(Logger::INFO,
                    "Feature '#{feature_flag_key}' is not enabled for user '#{user_id}'.")
        return false
      end

      variation = decision['variation']
      if decision.source == Optimizely::DecisionService::DECISION_SOURCE_EXPERIMENT
        # Send event if Decision came from an experiment.
        send_impression(decision.experiment, variation['key'], user_id, attributes)
      else
        @logger.log(Logger::DEBUG,
                    "The user '#{user_id}' is not being experimented on in feature '#{feature_flag_key}'.")
      end

      if variation['featureEnabled'] == true
        @logger.log(Logger::INFO,
                    "Feature '#{feature_flag_key}' is enabled for user '#{user_id}'.")
        return true
      else
        @logger.log(Logger::INFO,
                    "Feature '#{feature_flag_key}' is not enabled for user '#{user_id}'.")
        return false
      end
    end

    # Gets keys of all feature flags which are enabled for the user.
    #
    # @param user_id -  ID for user.
    # @param attributes - Dict representing user attributes.
    # @return [feature flag keys] A List of feature flag keys that are enabled for the user.

    def get_enabled_features(user_id, attributes = nil)
      enabled_features = []

      unless @is_valid
        @logger.log(Logger::ERROR, InvalidDatafileError.new('get_enabled_features').message)
        return enabled_features
      end

      return enabled_features unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      return enabled_features unless user_inputs_valid?(attributes)

      @config.feature_flags.each do |feature|
        enabled_features.push(feature['key']) if is_feature_enabled(
          feature['key'],
          user_id,
          attributes
        ) == true
      end
      enabled_features
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
      unless @is_valid
        @logger.log(Logger::ERROR, InvalidDatafileError.new('get_feature_variable_string').message)
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
      unless @is_valid
        @logger.log(Logger::ERROR, InvalidDatafileError.new('get_feature_variable_boolean').message)
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
      unless @is_valid
        @logger.log(Logger::ERROR, InvalidDatafileError.new('get_feature_variable_double').message)
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
      unless @is_valid
        @logger.log(Logger::ERROR, InvalidDatafileError.new('get_feature_variable_integer').message)
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

    private

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

      feature_flag = @config.get_feature_flag_from_key(feature_flag_key)
      unless feature_flag
        @logger.log(Logger::INFO, "No feature flag was found for key '#{feature_flag_key}'.")
        return nil
      end

      variable = @config.get_feature_variable(feature_flag, variable_key)

      # Error message logged in ProjectConfig- get_feature_flag_from_key
      return nil if variable.nil?

      feature_enabled = false

      # Returns nil if type differs
      if variable['type'] != variable_type
        @logger.log(Logger::WARN,
                    "Requested variable as type '#{variable_type}' but variable '#{variable_key}' is of type '#{variable['type']}'.")
        return nil
      else
        source_string = 'ROLLOUT'
        decision = @decision_service.get_variation_for_feature(feature_flag, user_id, attributes)
        variable_value = variable['defaultValue']
        if decision
          variation = decision['variation']
          if decision['source'] == Optimizely::DecisionService::DECISION_SOURCE_EXPERIMENT
            experiment_key = decision.experiment['key']
            variation_key = variation['key']
            source_string = 'EXPERIMENT'
          end
          feature_enabled = variation['featureEnabled']
          variation_variable_usages = @config.variation_id_to_variable_usage_map[variation['id']]
          variable_id = variable['id']
          if variation_variable_usages&.key?(variable_id)
            variable_value = variation_variable_usages[variable_id]['value']
            @logger.log(Logger::INFO,
                        "Got variable value '#{variable_value}' for variable '#{variable_key}' of feature flag '#{feature_flag_key}'.")
          else
            @logger.log(Logger::DEBUG,
                        "Variable '#{variable_key}' is not used in variation '#{variation['key']}'. Returning the default variable value '#{variable_value}'.")
          end
        else
          @logger.log(Logger::INFO,
                      "User '#{user_id}' was not bucketed into any variation for feature flag '#{feature_flag_key}'. Returning the default variable value '#{variable_value}'.")
        end
      end

      variable_value = Helpers::VariableType.cast_value_to_type(variable_value, variable_type, @logger)

      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        Helpers::Constants::DECISION_INFO_TYPES['FEATURE_VARIABLE'], user_id, attributes,
        decision_info: {
          feature_key: feature_flag_key,
          feature_enabled: feature_enabled,
          variable_key: variable_key,
          variable_type: variable_type,
          variable_value: variable_value,
          source: source_string,
          source_experiment_key: experiment_key,
          source_variation_key: variation_key
        }
      )

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

    def validate_instantiation_options(datafile, skip_json_validation)
      unless skip_json_validation
        raise InvalidInputError, 'datafile' unless Helpers::Validator.datafile_valid?(datafile)
      end

      raise InvalidInputError, 'logger' unless Helpers::Validator.logger_valid?(@logger)
      raise InvalidInputError, 'error_handler' unless Helpers::Validator.error_handler_valid?(@error_handler)
      raise InvalidInputError, 'event_dispatcher' unless Helpers::Validator.event_dispatcher_valid?(@event_dispatcher)
    end

    def send_impression(experiment, variation_key, user_id, attributes = nil)
      experiment_key = experiment['key']
      variation_id = @config.get_variation_id_from_key(experiment_key, variation_key)
      impression_event = @event_builder.create_impression_event(experiment, variation_id, user_id, attributes)
      @logger.log(Logger::INFO,
                  "Dispatching impression event to URL #{impression_event.url} with params #{impression_event.params}.")
      begin
        @event_dispatcher.dispatch_event(impression_event)
      rescue => e
        @logger.log(Logger::ERROR, "Unable to dispatch impression event. Error: #{e}")
      end
      variation = @config.get_variation_from_id(experiment_key, variation_id)
      @notification_center.send_notifications(
        NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
        experiment, user_id, attributes, variation, impression_event
      )
    end
  end
end
