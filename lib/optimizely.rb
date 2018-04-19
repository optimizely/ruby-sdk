# frozen_string_literal: true

#
#    Copyright 2016-2018, Optimizely and contributors
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
    # Boolean representing if the instance represents a usable Optimizely Project
    attr_reader :is_valid

    attr_reader :config
    attr_reader :decision_service
    attr_reader :error_handler
    attr_reader :event_builder
    attr_reader :event_dispatcher
    attr_reader :logger
    attr_reader :notification_center

    def initialize(datafile, event_dispatcher = nil, logger = nil, error_handler = nil, skip_json_validation = false, user_profile_service = nil)
      # Constructor for Projects.
      #
      # datafile - JSON string representing the project.
      # event_dispatcher - Provides a dispatch_event method which if given a URL and params sends a request to it.
      # logger - Optional component which provides a log method to log messages. By default nothing would be logged.
      # error_handler - Optional component which provides a handle_error method to handle exceptions.
      #                 By default all exceptions will be suppressed.
      # user_profile_service - Optional component which provides methods to store and retreive user profiles.
      # skip_json_validation - Optional boolean param to skip JSON schema validation of the provided datafile.

      @is_valid = true
      @logger = logger || NoOpLogger.new
      @error_handler = error_handler || NoOpErrorHandler.new
      @event_dispatcher = event_dispatcher || EventDispatcher.new
      @user_profile_service = user_profile_service

      begin
        validate_instantiation_options(datafile, skip_json_validation)
      rescue InvalidInputError => e
        @is_valid = false
        logger = SimpleLogger.new
        logger.log(Logger::ERROR, e.message)
        return
      end

      begin
        @config = ProjectConfig.new(datafile, @logger, @error_handler)
      rescue
        @is_valid = false
        logger = SimpleLogger.new
        logger.log(Logger::ERROR, InvalidInputError.new('datafile').message)
        return
      end

      unless @config.parsing_succeeded?
        @is_valid = false
        logger = SimpleLogger.new
        logger.log(Logger::ERROR, InvalidDatafileVersionError.new.message)
        return
      end

      @decision_service = DecisionService.new(@config, @user_profile_service)
      @event_builder = EventBuilder.new(@config, logger)
      @notification_center = NotificationCenter.new(@logger, @error_handler)
    end

    def activate(experiment_key, user_id, attributes = nil)
      # Buckets visitor and sends impression event to Optimizely.
      #
      # experiment_key - Experiment which needs to be activated.
      # user_id - String ID for user.
      # attributes - Hash representing user attributes and values to be recorded.
      #
      # Returns variation key representing the variation the user will be bucketed in.
      # Returns nil if experiment is not Running, if user is not in experiment, or if datafile is invalid.

      unless @is_valid
        logger = SimpleLogger.new
        logger.log(Logger::ERROR, InvalidDatafileError.new('activate').message)
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

    def get_variation(experiment_key, user_id, attributes = nil)
      # Gets variation where visitor will be bucketed.
      #
      # experiment_key - Experiment for which visitor variation needs to be determined.
      # user_id - String ID for user.
      # attributes - Hash representing user attributes.
      #
      # Returns variation key where visitor will be bucketed.
      # Returns nil if experiment is not Running, if user is not in experiment, or if datafile is invalid.

      unless @is_valid
        logger = SimpleLogger.new
        logger.log(Logger::ERROR, InvalidDatafileError.new('get_variation').message)
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

    def set_forced_variation(experiment_key, user_id, variation_key)
      # Force a user into a variation for a given experiment.
      #
      # experiment_key - String - key identifying the experiment.
      # user_id - String - The user ID to be used for bucketing.
      # variation_key - The variation key specifies the variation which the user will
      #   be forced into. If nil, then clear the existing experiment-to-variation mapping.
      #
      # Returns - Boolean - indicates if the set completed successfully.

      @config.set_forced_variation(experiment_key, user_id, variation_key)
    end

    def get_forced_variation(experiment_key, user_id)
      # Gets the forced variation for a given user and experiment.
      #
      # experiment_key - String - Key identifying the experiment.
      # user_id - String - The user ID to be used for bucketing.
      #
      # Returns String|nil The forced variation key.

      forced_variation_key = nil
      forced_variation = @config.get_forced_variation(experiment_key, user_id)
      forced_variation_key = forced_variation['key'] if forced_variation

      forced_variation_key
    end

    def track(event_key, user_id, attributes = nil, event_tags = nil)
      # Send conversion event to Optimizely.
      #
      # event_key - Event key representing the event which needs to be recorded.
      # user_id - String ID for user.
      # attributes - Hash representing visitor attributes and values which need to be recorded.
      # event_tags - Hash representing metadata associated with the event.

      unless @is_valid
        logger = SimpleLogger.new
        logger.log(Logger::ERROR, InvalidDatafileError.new('track').message)
        return nil
      end

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          event_key: event_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

      return nil unless user_inputs_valid?(attributes, event_tags)

      experiment_ids = @config.get_experiment_ids_for_event(event_key)
      if experiment_ids.empty?
        @config.logger.log(Logger::INFO, "Not tracking user '#{user_id}'.")
        return nil
      end

      # Filter out experiments that are not running or that do not include the user in audience conditions

      experiment_variation_map = get_valid_experiments_for_event(event_key, user_id, attributes)

      # Don't track events without valid experiments attached
      if experiment_variation_map.empty?
        @logger.log(Logger::INFO, "There are no valid experiments for event '#{event_key}' to track.")
        return nil
      end

      conversion_event = @event_builder.create_conversion_event(event_key, user_id, attributes,
                                                                event_tags, experiment_variation_map)
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

    def is_feature_enabled(feature_flag_key, user_id, attributes = nil)
      # Determine whether a feature is enabled.
      # Sends an impression event if the user is bucketed into an experiment using the feature.
      #
      # feature_flag_key - String unique key of the feature.
      # userId - String ID of the user.
      # attributes - Hash representing visitor attributes and values which need to be recorded.
      #
      # Returns True if the feature is enabled.
      #         False if the feature is disabled.
      #         False if the feature is not found.

      unless @is_valid
        logger = SimpleLogger.new
        logger.log(Logger::ERROR, InvalidDatafileError.new('is_feature_enabled').message)
        return false
      end

      return false unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          feature_flag_key: feature_flag_key,
          user_id: user_id
        }, @logger, Logger::ERROR
      )

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
      unless variation['featureEnabled']
        @logger.log(Logger::INFO,
                    "Feature '#{feature_flag_key}' is not enabled for user '#{user_id}'.")
        return false
      end

      if decision.source == Optimizely::DecisionService::DECISION_SOURCE_EXPERIMENT
        # Send event if Decision came from an experiment.
        send_impression(decision.experiment, variation['key'], user_id, attributes)
      else
        @logger.log(Logger::DEBUG,
                    "The user '#{user_id}' is not being experimented on in feature '#{feature_flag_key}'.")
      end
      @logger.log(Logger::INFO, "Feature '#{feature_flag_key}' is enabled for user '#{user_id}'.")

      true
    end

    def get_enabled_features(user_id, attributes = nil)
      # Gets keys of all feature flags which are enabled for the user.
      # Args:
      #   user_id: ID for user.
      #   attributes: Dict representing user attributes.
      # Returns:
      #   A List of feature flag keys that are enabled for the user.
      #
      enabled_features = []

      unless @is_valid
        logger = SimpleLogger.new
        logger.log(Logger::ERROR, InvalidDatafileError.new('get_enabled_features').message)
        return enabled_features
      end

      return enabled_features unless Optimizely::Helpers::Validator.inputs_valid?({user_id: user_id}, @logger, Logger::ERROR)

      @config.feature_flags.each do |feature|
        enabled_features.push(feature['key']) if is_feature_enabled(
          feature['key'],
          user_id,
          attributes
        ) == true
      end
      enabled_features
    end

    def get_feature_variable_string(feature_flag_key, variable_key, user_id, attributes = nil)
      # Get the String value of the specified variable in the feature flag.
      #
      # feature_flag_key - String key of feature flag the variable belongs to
      # variable_key - String key of variable for which we are getting the string value
      # user_id - String user ID
      # attributes - Hash representing visitor attributes and values which need to be recorded.
      #
      # Returns the string variable value.
      # Returns nil if the feature flag or variable are not found.

      variable_value = get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['STRING'],
        user_id,
        attributes
      )

      variable_value
    end

    def get_feature_variable_boolean(feature_flag_key, variable_key, user_id, attributes = nil)
      # Get the Boolean value of the specified variable in the feature flag.
      #
      # feature_flag_key - String key of feature flag the variable belongs to
      # variable_key - String key of variable for which we are getting the string value
      # user_id - String user ID
      # attributes - Hash representing visitor attributes and values which need to be recorded.
      #
      # Returns the boolean variable value.
      # Returns nil if the feature flag or variable are not found.

      variable_value = get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['BOOLEAN'],
        user_id,
        attributes
      )

      variable_value
    end

    def get_feature_variable_double(feature_flag_key, variable_key, user_id, attributes = nil)
      # Get the Double value of the specified variable in the feature flag.
      #
      # feature_flag_key - String key of feature flag the variable belongs to
      # variable_key - String key of variable for which we are getting the string value
      # user_id - String user ID
      # attributes - Hash representing visitor attributes and values which need to be recorded.
      #
      # Returns the double variable value.
      # Returns nil if the feature flag or variable are not found.

      variable_value = get_feature_variable_for_type(
        feature_flag_key,
        variable_key,
        Optimizely::Helpers::Constants::VARIABLE_TYPES['DOUBLE'],
        user_id,
        attributes
      )

      variable_value
    end

    def get_feature_variable_integer(feature_flag_key, variable_key, user_id, attributes = nil)
      # Get the Integer value of the specified variable in the feature flag.
      #
      # feature_flag_key - String key of feature flag the variable belongs to
      # variable_key - String key of variable for which we are getting the string value
      # user_id - String user ID
      # attributes - Hash representing visitor attributes and values which need to be recorded.
      #
      # Returns the integer variable value.
      # Returns nil if the feature flag or variable are not found.

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
          variable_type: variable_type,
          user_id: user_id
        },
        @logger, Logger::ERROR
      )

      feature_flag = @config.get_feature_flag_from_key(feature_flag_key)
      unless feature_flag
        @logger.log(Logger::INFO, "No feature flag was found for key '#{feature_flag_key}'.")
        return nil
      end

      variable = @config.get_feature_variable(feature_flag, variable_key)

      # Error message logged in ProjectConfig- get_feature_flag_from_key
      return nil if variable.nil?

      # Returns nil if type differs
      if variable['type'] != variable_type
        @logger.log(Logger::WARN,
                    "Requested variable as type '#{variable_type}' but variable '#{variable_key}' is of type '#{variable['type']}'.")
        return nil
      else
        decision = @decision_service.get_variation_for_feature(feature_flag, user_id, attributes)
        variable_value = variable['defaultValue']
        if decision
          variation = decision['variation']
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

      variable_value
    end

    def get_valid_experiments_for_event(event_key, user_id, attributes)
      # Get the experiments that we should be tracking for the given event.
      #
      # event_key - Event key representing the event which needs to be recorded.
      # user_id - String ID for user.
      # attributes - Map of attributes of the user.
      #
      # Returns Map where each object contains the ID of the experiment to track and the ID of the variation the user
      # is bucketed into.

      valid_experiments = {}
      experiment_ids = @config.get_experiment_ids_for_event(event_key)
      experiment_ids.each do |experiment_id|
        experiment_key = @config.get_experiment_key(experiment_id)
        variation_key = get_variation(experiment_key, user_id, attributes)

        if variation_key.nil?
          @logger.log(Logger::INFO, "Not tracking user '#{user_id}' for experiment '#{experiment_key}'.")
          next
        end

        variation_id = @config.get_variation_id_from_key(experiment_key, variation_key)
        valid_experiments[experiment_id] = variation_id
      end

      valid_experiments
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
