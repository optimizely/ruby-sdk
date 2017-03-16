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

      def get_revenue_value(event_tags)
        # Grab the revenue value from the event tags. "revenue" is a reserved keyword.
        #
        # event_tags - Hash representing metadata associated with the event.
        # Returns revenue value as an integer number
        # Returns nil if revenue can't be retrieved from the event tags.

        if event_tags.nil? or !Helpers::Validator.attributes_valid?(event_tags)
          return nil
        end

        unless event_tags.has_key?('revenue')
          return nil
        end

        logger = SimpleLogger.new
        raw_value = event_tags['revenue']

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
    end
  end
end
