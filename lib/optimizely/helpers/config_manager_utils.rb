# frozen_string_literal: true

#
#    Copyright 2019, Optimizely and contributors
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
require 'optimizely/config/datafile_project_config'
module Optimizely
  module Helpers
    module ConfigManagerUtils
      module_function

      def create_project_config_from_datafile(datafile, logger, error_handler, skip_json_validation)
        # Looks up and sets datafile and config based on response body.
        #
        # datafile - JSON string representing the Optimizely project.
        # logger - Provides a logger instance.
        # error_handler - Provides a handle_error method to handle exceptions.
        # skip_json_validation - Optional boolean param which allows skipping JSON schema
        #                       validation upon object invocation. By default JSON schema validation will be performed.
        # Returns instance of DatafileProjectConfig, nil otherwise.
        if !skip_json_validation && !Helpers::Validator.datafile_valid?(datafile)
          default_logger = SimpleLogger.new
          default_logger.log(Logger::ERROR, InvalidInputError.new('datafile').message)
          return nil
        end

        begin
          config = DatafileProjectConfig.new(datafile, logger, error_handler)
        rescue StandardError => e
          default_logger = SimpleLogger.new
          error_msg = e.class == InvalidDatafileVersionError ? e.message : InvalidInputError.new('datafile').message
          error_to_handle = e.class == InvalidDatafileVersionError ? InvalidDatafileVersionError : InvalidInputError
          default_logger.log(Logger::ERROR, error_msg)
          error_handler.handle_error error_to_handle
          return nil
        end

        config
      end
    end
  end
end
