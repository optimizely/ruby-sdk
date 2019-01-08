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
require_relative 'constants'
require 'json'
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

      def attribute_valid?(attribute_key, attribute_value)
        # Determines if provided attribute_key and attribute_value are valid.
        #
        # attribute_key - Variable which needs to be validated.
        # attribute_value - Variable which needs to be validated.
        #
        # Returns boolean depending on validity of attribute_key and attribute_value.

        return false unless attribute_key.is_a?(String) || attribute_key.is_a?(Symbol)

        return true if (boolean? attribute_value) || (attribute_value.is_a? String)

        finite_number?(attribute_value)
      end

      def event_tags_valid?(event_tags)
        # Determines if provided event tags are valid.
        #
        # event_tags - Event tags to be validated.
        #
        # Returns boolean depending on validity of event tags.

        event_tags.is_a?(Hash)
      end

      def datafile_valid?(datafile)
        # Determines if a given datafile is valid.
        #
        # datafile - String JSON representing the project.
        #
        # Returns boolean depending on validity of datafile.

        begin
          datafile = JSON.parse(datafile)
        rescue
          return false
        end

        JSON::Validator.validate(Helpers::Constants::JSON_SCHEMA_V2, datafile)
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

      def string_numeric?(str)
        !Float(str).nil?
      rescue
        false
      end

      def inputs_valid?(variables, logger = NoOpLogger.new, level = Logger::ERROR)
        # Determines if values of variables in given array are non empty string.
        #
        # variables - array values to validate.
        #
        # logger - logger.
        #
        # Returns boolean True if all of the values are valid, False otherwise.

        return false unless variables.respond_to?(:each) && !variables.empty?

        is_valid = true
        if variables.include? :user_id
          # Empty str is a valid user ID.
          unless variables[:user_id].is_a?(String)
            is_valid = false
            logger.log(level, "#{Constants::INPUT_VARIABLES['USER_ID']} is invalid")
          end
          variables.delete :user_id
        end

        variables.each do |key, value|
          next if value.is_a?(String) && !value.empty?

          is_valid = false
          next unless logger_valid?(logger) && level

          logger.log(level, "#{Constants::INPUT_VARIABLES[key.to_s.upcase]} is invalid")
        end
        is_valid
      end

      def boolean?(value)
        # Returns true if given value type is boolean.
        #         false otherwise.

        value.is_a?(TrueClass) || value.is_a?(FalseClass)
      end

      def same_types?(value_1, value_2)
        # Returns true if given values are of same types.
        #         false otherwise.

        return true if boolean?(value_1) && boolean?(value_2)
        return true if value_1.is_a?(Integer) && value_2.is_a?(Integer)

        value_1.class == value_2.class
      end

      def finite_number?(value)
        # Returns true if the given value is a number, enforces
        #   absolute limit of 2^53 and restricts NaN, Infinity, -Infinity.
        #   false otherwise.

        value.is_a?(Numeric) && value.to_f.finite? && value.abs <= Constants::FINITE_NUMBER_LIMIT
      end
    end
  end
end
