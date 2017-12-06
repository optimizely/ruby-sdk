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

module Optimizely
  module Helpers
    module VariableType
      module_function

      def cast_value_to_type(value, variable_type, logger)
        # Attempts to cast the given value to the specified type
        #
        # value - The string value to cast
        # variable_type - String variable type
        #
        # Returns the cast value or nil if not able to cast
        return_value = nil

        case variable_type
        when 'boolean'
          return_value = value == 'true'
        when 'double'
          begin
            return_value = Float(value)
          rescue => e
            logger.log(Logger::ERROR, "Unable to cast variable value '#{value}' to type "\
                                      "'#{variable_type}': #{e.message}.")
          end
        when 'integer'
          begin
            return_value = Integer(value)
          rescue => e
            logger.log(Logger::ERROR, "Unable to cast variable value '#{value}' to type "\
                                      "'#{variable_type}': #{e.message}.")
          end
        else
          # default case is string
          return_value = value
        end

        return_value
      end
    end
  end
end
