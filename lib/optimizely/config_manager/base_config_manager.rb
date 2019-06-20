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

require 'optimizely/error_handler'
require 'optimizely/logger'

module Optimizely
  class BaseConfigManager
    # Interface for fetching ProjectConfig instance.
    #
    # Returns ProjectConfig instance.

    def initialize(logger = nil, error_handler = nil)
      # logger - Provides a logger instance.
      # error_handler - Provides a handle_error method to handle exceptions.

      @logger = logger || NoOpLogger.new
      @error_handler = error_handler || NoOpErrorHandler.new
    end

    # Get config for use by Optimizely.
    # The config should be an instance of ProjectConfig.
    def get_config
      throw :GetConfigError
    end
  end
end
