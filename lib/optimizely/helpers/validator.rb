require_relative 'constants'
require 'json-schema'

module Optimizely
  module Helpers
    module Validator
      module_function

      def attributes_valid?(attributes)
        # Determines if provided attributes are valid.
        #
        # attributes - User attributes to be validated.
        #
        # Returns boolean depending on validity of attributes.

        attributes.is_a?(Hash)
      end

      def datafile_valid?(datafile)
        # Determines if a given datafile is valid.
        #
        # datafile - String JSON representing the project.
        #
        # Returns boolean depending on validity of datafile.

        JSON::Validator.validate(Helpers::Constants::JSON_SCHEMA_V1, datafile)
      end

      def error_handler_valid?(error_handler)
        # Determines if a given error handler is valid.
        #
        # error_handler - error_handler to be validated.
        #
        # Returns boolean depending on whether error_handler has a handle_error method.

        error_handler.respond_to?(:handle_error)
      end

      def event_dispatcher_valid?(event_dispatcher)
        # Determines if a given event dispatcher is valid.
        #
        # event_dispatcher - event_dispatcher to be validated.
        #
        # Returns boolean depending on whether event_dispatcher has a dispatch_event method.

        event_dispatcher.respond_to?(:dispatch_event)
      end

      def logger_valid?(logger)
        # Determines if a given logger is valid.
        #
        # logger - logger to be validated.
        #
        # Returns boolean depending on whether logger has a log method.

        logger.respond_to?(:log)
      end
    end
  end
end
