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
require_relative '../error_handler'
require_relative 'exceptions'
require_relative 'helpers/constants'
require_relative 'helpers/validator'
require_relative 'logger'
require_relative 'notification_center'
require_relative 'project_config'
require_relative 'project_config_manager'

require 'net/http'

module Optimizely
  class PollingProjectConfigManager < ProjectConfigManager
    # Config manager that polls for the datafile and updated ProjectConfig based on an update interval.

    # Initialize config manager. One of sdk_key or url has to be set to be able to use.
    #
    # sdk_key - Optional string uniquely identifying the datafile.
    # datafile: Optional JSON string representing the project.
    # update_interval - Optional floating point number representing time interval in seconds
    #                  at which to request datafile and set ProjectConfig.
    # url - Optional string representing URL from where to fetch the datafile. If set it supersedes the sdk_key.
    # url_template - Optional string template which in conjunction with sdk_key
    #               determines URL from where to fetch the datafile.
    # logger - Provides a logger instance.
    # error_handler - Provides a handle_error method to handle exceptions.
    # skip_json_validation - Optional boolean param which allows skipping JSON schema
    #                       validation upon object invocation. By default JSON schema validation will be performed.
    def initialize(
      sdk_key = nil,
      datafile = nil,
      update_interval = nil,
      url = nil,
      url_template = nil,
      _logger = nil,
      _error_handler = nil,
      skip_json_validation = false
    )

      url_template ||= Helpers::Constants::CONFIG_MANAGER['DATAFILE_URL_TEMPLATE']
      @datafile_url = get_datafile_url(sdk_key, url, url_template)
      @update_interval = update_interval || Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']
      update_interval(update_interval)
      @last_modified = nil
      @config = nil
      @validate_schema = !skip_json_validation
      @polling_thread = Thread.new { run }
      set_config(datafile) if datafile
    end

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

      # TODO(rashid): Add notification listener.
      @logger.log(Logger::DEBUG, 'Received new datafile and updated config.')
    end

    def get_datafile_url(sdk_key, url, url_template)
      # Helper method to determine URL from where to fetch the datafile.
      # sdk_key - Key uniquely identifying the datafile.
      # url - String representing URL from which to fetch the datafile.
      # url_template - String representing template which is filled in with
      #               SDK key to determine URL from which to fetch the datafile.
      # Returns String representing URL to fetch datafile from.

      raise InvalidInputsError, 'Must provide at least one of sdk_key or url.' if sdk_key.nil? && url.nil?

      return (url_template % sdk_key) unless url

      url
    end

    def update_interval(update_interval)
      # Helper method to set frequency at which datafile has to be polled and ProjectConfig updated.
      #
      # update_interval - Time in seconds after which to update datafile.

      # If polling interval is less than minimum allowed interval then set it to default update interval.

      return unless @update_interval < Helpers::Constants::CONFIG_MANAGER['MIN_UPDATE_INTERVAL']

      @logger.log(
        Logger::DEBUG,
        "Invalid update_interval #{update_interval} provided. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']}"
      )
      @update_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']
    end

    def handle_response(response)
      # Helper method to handle response containing datafile.
      #
      # response - requests.Response

      # Leave datafile and config unchanged if it has not been modified.
      if response.code == Net::HTTPNotModified
        @logger.log(
          Logger::DEBUG,
          "Not updating config as datafile has not updated since #{@last_modified}."
        )
        return
      end

      @last_modified = response[Helpers::Constants::HTTP_HEADERS['LAST_MODIFIED']]
      @config = set_config response.body
    end

    def fetch_datafile
      # Fetch datafile and set ProjectConfig.
      begin
        uri = URI(@datafile_url)
        request = Net::HTTP::Get.new(uri)
        request[Helpers::Constants::HTTP_HEADERS['IF_MODIFIED_SINCE']] = @last_modified if @last_modified
        response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: Helpers::Constants::CONFIG_MANAGER['REQUEST_TIMEOUT']) do |http|
          http.request(request)
        end
      rescue StandardError => e
        @logger.log(
          Logger::ERROR,
          "Fetching datafile from #{@datafile_url} failed. Error: #{e}"
        )
        return
      end

      handle_response response
    end

    def running
      # Check if polling thread is alive or not.
      @polling_thread.alive?
    end

    def run
      # Triggered as part of the thread which fetches the datafile and sleeps until next update interval.
      while running
        fetch_datafile
        sleep @update_interval
      end
    end
  end
end
