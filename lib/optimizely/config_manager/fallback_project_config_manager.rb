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

require_relative 'project_config_manager'

module Optimizely
  class FallbackProjectConfigManager < ProjectConfigManager
    # Implementation of ProjectConfigManager interface.
    # Returns the stored ProjectConfig instance.

    def initialize(datafile = nil, logger = nil, error_handler = nil, skip_json_validation = false)
      @logger = logger
      @error_handler = error_handler
      @config = nil
      @validate_schema = !skip_json_validation
      set_config(datafile)
    end

    def get_config
      # Returns object ProjectConfig instance.
      @config
    end

    private

    def set_config(datafile)
      # Looks up and sets datafile and config based on response body.
      #
      # datafile: JSON string representing the Optimizely project.

      if @validate_schema
        unless Helpers::Validator.datafile_valid?(datafile)
          @logger.log(Logger::ERROR, InvalidDatafileError.new('datafile').message)
          return
        end
      end

      begin
        @config = ProjectConfig.new(datafile, @logger, @error_handler)
      rescue StandardError => e
        @logger = SimpleLogger.new
        error_msg = e.class == InvalidDatafileVersionError ? e.message : InvalidInputError.new('datafile').message
        error_to_handle = e.class == InvalidDatafileVersionError ? InvalidDatafileVersionError : InvalidInputError
        @logger.log(Logger::ERROR, error_msg)
        @error_handler.handle_error error_to_handle
        return
      end
      @logger.log(Logger::DEBUG, 'Received new datafile and updated config.')
    end
  end
end
