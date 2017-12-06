# frozen_string_literal: true

#
#    Copyright 2017, Optimizely and contributors
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
require 'optimizely/logger'
require 'optimizely/helpers/validator'

module Optimizely
  module Helpers
    module EventTagUtils
      module_function

      REVENUE_EVENT_METRIC_NAME = 'revenue'
      NUMERIC_EVENT_METRIC_NAME = 'value'

      def string_numeric?(str)
        !Float(str).nil?
      rescue
        false
      end

      def get_revenue_value(event_tags)
        # Grab the revenue value from the event tags. "revenue" is a reserved keyword.
        # The revenue value must be an integer.
        #
        # event_tags - Hash representing metadata associated with the event.
        # Returns revenue value as an integer number
        # Returns nil if revenue can't be retrieved from the event tags.

        if event_tags.nil? || !Helpers::Validator.event_tags_valid?(event_tags)
          return nil
        end

        return nil unless event_tags.key?(REVENUE_EVENT_METRIC_NAME)

        logger = SimpleLogger.new
        raw_value = event_tags[REVENUE_EVENT_METRIC_NAME]

        unless raw_value.is_a? Numeric
          logger.log(Logger::WARN, "Failed to parse revenue value #{raw_value} from event tags.")
          return nil
        end

        if raw_value.is_a? Float
          logger.log(Logger::WARN, "Failed to parse revenue value #{raw_value} from event tags.")
          return nil
        end

        logger.log(Logger::INFO, "Parsed revenue value #{raw_value} from event tags.")
        raw_value
      end

      def get_numeric_value(event_tags, logger = nil)
        # Grab the numeric event value from the event tags. "value" is a reserved keyword.
        # The value of 'value' can be a float or a numeric string
        #
        # event_tags - +Hash+ representing metadata associated with the event.
        # Returns  +Number+ | +nil+ if value can't be retrieved from the event tags.
        logger = SimpleLogger.new if logger.nil?

        if event_tags.nil?
          logger.log(Logger::DEBUG, 'Event tags is undefined.')
          return nil
        end

        unless Helpers::Validator.event_tags_valid?(event_tags)
          logger.log(Logger::DEBUG, 'Event tags is not a dictionary.')
          return nil
        end

        unless event_tags.key?(NUMERIC_EVENT_METRIC_NAME)
          logger.log(Logger::DEBUG, 'The numeric metric key is not defined in the event tags.')
          return nil
        end

        if event_tags[NUMERIC_EVENT_METRIC_NAME].nil?
          logger.log(Logger::DEBUG, 'The numeric metric key is null.')
          return nil
        end

        raw_value = event_tags[NUMERIC_EVENT_METRIC_NAME]

        if raw_value.is_a?(TrueClass) || raw_value.is_a?(FalseClass)
          logger.log(Logger::DEBUG, 'Provided numeric value is a boolean, which is an invalid format.')
          return nil
        end

        if raw_value.is_a?(Array) || raw_value.is_a?(Hash) || raw_value.to_f.nan? || raw_value.to_f.infinite?
          logger.log(Logger::DEBUG, 'Provided numeric value is in an invalid format.')
          return nil
        end

        unless Helpers::Validator.string_numeric?(raw_value)
          logger.log(Logger::DEBUG, 'Provided numeric value is not a numeric string.')
          return nil
        end

        raw_value = raw_value.to_f

        logger.log(Logger::INFO, "The numeric metric value #{raw_value} will be sent to results.")

        raw_value
      end
    end
  end
end
