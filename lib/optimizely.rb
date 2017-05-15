#
#    Copyright 2016-2017, Optimizely and contributors
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
require_relative 'optimizely/helpers/group'
require_relative 'optimizely/helpers/validator'
require_relative 'optimizely/logger'
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

    def initialize(datafile, event_dispatcher = nil, logger = nil, error_handler = nil, skip_json_validation = false)
      # Constructor for Projects.
      #
      # datafile - JSON string representing the project.
      # event_dispatcher - Provides a dispatch_event method which if given a URL and params sends a request to it.
      # logger - Optional param which provides a log method to log messages. By default nothing would be logged.
      # error_handler - Optional param which provides a handle_error method to handle exceptions.
      #                 By default all exceptions will be suppressed.
      # skip_json_validation - Optional boolean param to skip JSON schema validation of the provided datafile.

      @is_valid = true
      @logger = logger || NoOpLogger.new
      @error_handler = error_handler || NoOpErrorHandler.new
      @event_dispatcher = event_dispatcher || EventDispatcher.new

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

      @decision_service = DecisionService.new(@config)
      @event_builder = EventBuilderV2.new(@config)
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

      variation_key = get_variation(experiment_key, user_id, attributes)

      if variation_key.nil?
        @logger.log(Logger::INFO, "Not activating user '#{user_id}'.")
        return nil
      end

      # Create and dispatch impression event
      variation_id = @config.get_variation_id_from_key(experiment_key, variation_key)
      impression_event = @event_builder.create_impression_event(experiment_key, variation_id, user_id, attributes)
      @logger.log(Logger::INFO,
                  'Dispatching impression event to URL %s with params %s.' % [impression_event.url,
                                                                              impression_event.params])
      begin
        @event_dispatcher.dispatch_event(impression_event)
      rescue => e
        @logger.log(Logger::ERROR, "Unable to dispatch impression event. Error: #{e}")
      end

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

      unless user_inputs_valid?(attributes)
        @logger.log(Logger::INFO, "Not activating user '#{user_id}.")
        return nil
      end

      variation_id = @decision_service.get_variation(experiment_key, user_id, attributes)

      unless variation_id.nil?
        return @config.get_variation_key_from_id(experiment_key, variation_id)
      end
      nil
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

      if event_tags and event_tags.is_a? Numeric
        event_tags = {
          'revenue' => event_tags
        }
        @logger.log(Logger::WARN, 'Event value is deprecated in track call. Use event tags to pass in revenue value instead.')
      end

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
                  'Dispatching conversion event to URL %s with params %s.' % [conversion_event.url,
                                                                              conversion_event.params])
      begin
        @event_dispatcher.dispatch_event(conversion_event)
      rescue => e
        @logger.log(Logger::ERROR, "Unable to dispatch conversion event. Error: #{e}")
      end
    end

    private

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

      if !attributes.nil? && !attributes_valid?(attributes)
        return false
      end

      if !event_tags.nil? && !event_tags_valid?(event_tags)
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
        raise InvalidInputError.new('datafile') unless Helpers::Validator.datafile_valid?(datafile)
      end

      raise InvalidInputError.new('logger') unless Helpers::Validator.logger_valid?(@logger)
      raise InvalidInputError.new('error_handler') unless Helpers::Validator.error_handler_valid?(@error_handler)
      raise InvalidInputError.new('event_dispatcher') unless Helpers::Validator.event_dispatcher_valid?(@event_dispatcher)
    end
  end
end
