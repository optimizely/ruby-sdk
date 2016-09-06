require_relative 'optimizely/audience'
require_relative 'optimizely/bucketer'
require_relative 'optimizely/error_handler'
require_relative 'optimizely/event_builder'
require_relative 'optimizely/event_dispatcher'
require_relative 'optimizely/exceptions'
require_relative 'optimizely/helpers/group'
require_relative 'optimizely/helpers/validator'
require_relative 'optimizely/logger'
require_relative 'optimizely/project_config'

module Optimizely
  class Project
    attr_accessor :config
    attr_accessor :bucketer
    attr_accessor :event_builder
    attr_accessor :event_dispatcher
    attr_accessor :logger
    attr_accessor :error_handler

    EVENT_BUILDERS_BY_VERSION = {
      '1' => EventBuilderV1,
      '2' => EventBuilderV2
    }

    def initialize(datafile, event_dispatcher = nil, logger = nil, error_handler = nil, skip_json_validation = false)
      # Constructor for Projects.
      #
      # datafile - JSON string representing the project.
      # event_dispatcher - Provides a dispatch_event method which if given a URL and params sends a request to it.
      # logger - Optional param which provides a log method to log messages. By default nothing would be logged.
      # error_handler - Optional param which provides a handle_error method to handle exceptions.
      #                 By default all exceptions will be suppressed.
      # skip_json_validation - Optional boolean param to skip JSON schema validation of the provided datafile.

      @logger = logger || NoOpLogger.new
      @error_handler = error_handler || NoOpErrorHandler.new
      @event_dispatcher = event_dispatcher || EventDispatcher.new
      validate_inputs(datafile, skip_json_validation)

      @config = ProjectConfig.new(datafile, @logger, @error_handler)
      @bucketer = Bucketer.new(@config)
      event_builder = EVENT_BUILDERS_BY_VERSION[@config.version]
      @event_builder = event_builder.new(@config, @bucketer)

    end

    def activate(experiment_key, user_id, attributes = nil)
      # Buckets visitor and sends impression event to Optimizely.
      #
      # experiment_key - Experiment which needs to be activated.
      # user_id - String ID for user.
      # attributes - Hash representing user attributes and values to be recorded.
      #
      # Returns variation key representing the variation the user will be bucketed in.
      # Returns nil if experiment is not Running or if user is not in experiment.

      if attributes && !attributes_valid?(attributes)
        @logger.log(Logger::INFO, "Not activating user '#{user_id}'.")
        return nil
      end

      unless preconditions_valid?(experiment_key, user_id, attributes)
        @logger.log(Logger::INFO, "Not activating user '#{user_id}'.")
        return nil
      end

      variation_id = @bucketer.bucket(experiment_key, user_id)

      if not variation_id
        @logger.log(Logger::INFO, "Not activating user '#{user_id}'.")
        return nil
      end

      # Create and dispatch impression event
      impression_event = @event_builder.create_impression_event(experiment_key, variation_id, user_id, attributes)
      @logger.log(Logger::INFO,
                  'Dispatching impression event to URL %s with params %s.' % [impression_event.url,
                                                                              impression_event.params])
      @event_dispatcher.dispatch_event(impression_event)

      @config.get_variation_key_from_id(experiment_key, variation_id)
    end

    def get_variation(experiment_key, user_id, attributes = nil)
      # Gets variation where visitor will be bucketed.
      #
      # experiment_key - Experiment for which visitor variation needs to be determined.
      # user_id - String ID for user.
      # attributes - Hash representing user attributes.
      #
      # Returns variation key where visitor will be bucketed.
      # Returns nil if experiment is not Running or if user is not in experiment.

      if attributes && !attributes_valid?(attributes)
        @logger.log(Logger::INFO, "Not activating user '#{user_id}.")
        return nil
      end

      unless preconditions_valid?(experiment_key, user_id, attributes)
        @logger.log(Logger::INFO, "Not activating user '#{user_id}.")
        return nil
      end

      variation_id = @bucketer.bucket(experiment_key, user_id)
      @config.get_variation_key_from_id(experiment_key, variation_id)
    end

    def track(event_key, user_id, attributes = nil, event_value = nil)
      # Send conversion event to Optimizely.
      #
      # event_key - Goal key representing the event which needs to be recorded.
      # user_id - String ID for user.
      # attributes - Hash representing visitor attributes and values which need to be recorded.
      # event_value - Value associated with the event. Can be used to represent revenue in cents.

      # Create and dispatch conversion event

      return nil if attributes && !attributes_valid?(attributes)

      experiment_ids = @config.get_experiment_ids_for_goal(event_key)
      if experiment_ids.empty?
        @config.logger.log(Logger::INFO, "Not tracking user '#{user_id}'.")
        return nil
      end

      # Filter out experiments that are not running or that do not include the user in audience conditions
      valid_experiment_keys = []
      experiment_ids.each do |experiment_id|
        experiment_key = @config.experiment_id_map[experiment_id]['key']
        unless preconditions_valid?(experiment_key, user_id, attributes)
          @config.logger.log(Logger::INFO, "Not tracking user '#{user_id}' for experiment '#{experiment_key}'.")
          next
        end
        valid_experiment_keys.push(experiment_key)
      end

      # Don't track events without valid experiments attached
      return if valid_experiment_keys.empty?

      conversion_event = @event_builder.create_conversion_event(event_key, user_id, attributes,
                                                                event_value, valid_experiment_keys)
      @logger.log(Logger::INFO,
                  'Dispatching conversion event to URL %s with params %s.' % [conversion_event.url,
                                                                              conversion_event.params])
      @event_dispatcher.dispatch_event(conversion_event)
    end

    private

    def preconditions_valid?(experiment_key, user_id, attributes)
      # Validates preconditions for bucketing a user.
      #
      # experiment_key - String key for an experiment.
      # user_id - String ID of user.
      # attributes - Hash of user attributes.
      #
      # Returns boolean representing whether all preconditions are valid.

      unless @config.experiment_running?(experiment_key)
        @logger.log(Logger::INFO, "Experiment '#{experiment_key} is not running.")
        return false
      end

      unless Audience.user_in_experiment?(@config, experiment_key, attributes)
        @logger.log(Logger::INFO,
                    "User '#{user_id} does not meet the conditions to be in experiment '#{experiment_key}.")
        return false
      end

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

    def validate_inputs(datafile, skip_json_validation)
      unless skip_json_validation
        raise InvalidDatafileError unless Helpers::Validator.datafile_valid?(datafile)
      end

      raise InvalidLoggerError unless Helpers::Validator.logger_valid?(@logger)
      raise InvalidErrorHandlerError unless Helpers::Validator.error_handler_valid?(@error_handler)
      raise InvalidEventDispatcherError unless Helpers::Validator.event_dispatcher_valid?(@event_dispatcher)
    end
  end
end
