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
require_relative '../config/datafile_project_config'
require_relative '../error_handler'
require_relative '../exceptions'
require_relative '../helpers/constants'
require_relative '../logger'
require_relative '../notification_center'
require_relative '../project_config'
require_relative 'project_config_manager'
require_relative 'async_scheduler'
require 'httparty'
require 'json'
module Optimizely
  class HTTPProjectConfigManager < ProjectConfigManager
    # Config manager that polls for the datafile and updated ProjectConfig based on an update interval.

    attr_reader :config

    # Initialize config manager. One of sdk_key or url has to be set to be able to use.
    #
    # sdk_key - Optional string uniquely identifying the datafile. It's required unless a URL is passed in.
    # datafile: Optional JSON string representing the project.
    # polling_interval - Optional floating point number representing time interval in seconds
    #                  at which to request datafile and set ProjectConfig.
    # blocking_timeout -
    # auto_update -
    # start_by_default -
    # url - Optional string representing URL from where to fetch the datafile. If set it supersedes the sdk_key.
    # url_template - Optional string template which in conjunction with sdk_key
    #               determines URL from where to fetch the datafile.
    # logger - Provides a logger instance.
    # error_handler - Provides a handle_error method to handle exceptions.
    # skip_json_validation - Optional boolean param which allows skipping JSON schema
    #                       validation upon object invocation. By default JSON schema validation will be performed.
    def initialize(
      sdk_key: nil,
      url: nil,
      url_template: nil,
      polling_interval: nil,
      blocking_timeout: nil,
      auto_update: true,
      start_by_default: true,
      datafile: nil,
      logger: nil,
      error_handler: nil,
      skip_json_validation: false,
      notification_center: nil
    )
      @logger = logger || NoOpLogger.new
      @error_handler = error_handler || NoOpErrorHandler.new
      @datafile_url = get_datafile_url(sdk_key, url, url_template)
      @polling_interval = nil
      polling_interval(polling_interval)
      blocking_timeout ||= Helpers::Constants::CONFIG_MANAGER['BLOCKING_TIMEOUT']
      @blocking_timeout = blocking_timeout
      @last_modified = nil
      @async_scheduler = AsyncScheduler.new(method(:fetch_datafile), @polling_interval, auto_update, @logger)
      @async_scheduler.start! if start_by_default == true
      @skip_json_validation = skip_json_validation
      @notification_center = notification_center.is_a?(Optimizely::NotificationCenter) ? notification_center : NotificationCenter.new(@logger, @error_handler)
      @config = datafile.nil? ? nil : DatafileProjectConfig.create_project_config_from_datafile(datafile, @logger, @error_handler, @skip_json_validation)
      @mutex = Mutex.new
      @resource = ConditionVariable.new
    end

    def ready?
      !@config.nil?
    end

    def start!
      @async_scheduler.start!
    end

    def stop!
      @async_scheduler.stop!
    end

    def get_config
      # Get Project Config.

      # Returns config immediately if the config has been initialized. When a hardcoded
      # datafile is passed on init, config becomes ready immediately.

      return @config if ready?

      # If config hasn't been initalized, we check if the background datafile polling
      # thread is running. If it is, we wait and block maximum for @blocking_timeout.
      # If the config gets ready within this period, we return the updated config otherwise
      # we return None.
      if @async_scheduler.running
        @mutex.synchronize do
          @resource.wait(@mutex, @blocking_timeout)
          return @config
        end
      end

      @config
    end

    def fetch_datafile
      # Fetch datafile and set ProjectConfig.

      @logger.log(
        Logger::DEBUG,
        "Fetching datafile from #{@datafile_url}"
      )
      begin
        headers = {
          'Content-Type' => 'application/json'
        }

        headers[Helpers::Constants::HTTP_HEADERS['LAST_MODIFIED']] = @last_modified if @last_modified

        response = HTTParty.get(
          @datafile_url,
          headers: headers,
          timeout: Helpers::Constants::CONFIG_MANAGER['REQUEST_TIMEOUT']
        )
      rescue StandardError => e
        @logger.log(
          Logger::ERROR,
          "Fetching datafile from #{@datafile_url} failed. Error: #{e}"
        )
        return
      end

      handle_response response
    end

    private

    def polling_interval(polling_interval)
      # Sets frequency at which datafile has to be polled and ProjectConfig updated.
      #
      # polling_interval - Time in seconds after which to update datafile.

      # If polling interval is less than minimum allowed interval then set it to default update interval.

      if polling_interval.to_i >= Helpers::Constants::CONFIG_MANAGER['MIN_UPDATE_INTERVAL']
        @polling_interval = polling_interval
        return
      end

      @logger.log(
        Logger::DEBUG,
        "Invalid update_interval #{polling_interval} provided. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']}"
      )
      @polling_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']
    end

    def get_datafile_url(sdk_key, url, url_template)
      # Determines URL from where to fetch the datafile.
      # sdk_key - Key uniquely identifying the datafile.
      # url - String representing URL from which to fetch the datafile.
      # url_template - String representing template which is filled in with
      #               SDK key to determine URL from which to fetch the datafile.
      # Returns String representing URL to fetch datafile from.

      raise InvalidInputsError, 'Must provide at least one of sdk_key or url.' if sdk_key.nil? && url.nil?

      unless url
        url_template ||= Helpers::Constants::CONFIG_MANAGER['DATAFILE_URL_TEMPLATE']
        begin
          return (url_template % sdk_key)
        rescue
          raise InvalidInputsError, "Invalid url_template #{url_template} provided."
        end
      end

      url
    end

    def handle_response(response)
      # Helper method to handle response containing datafile.
      #
      # response - requests.Response

      # Leave datafile and config unchanged if it has not been modified.
      if response.code == '304'
        @logger.log(
          Logger::DEBUG,
          "Not updating config as datafile has not updated since #{@last_modified}."
        )
        return
      end

      @last_modified = response[Helpers::Constants::HTTP_HEADERS['LAST_MODIFIED']]
      config = DatafileProjectConfig.create_project_config_from_datafile(response.body, @logger, @error_handler, @skip_json_validation) if response.body
      return unless config

      previous_revision = @config.revision if @config
      return if previous_revision == config.revision

      unless ready?
        @config = config
        @mutex.synchronize { @resource.signal }
      end

      @config = config

      @notification_center.send_notifications(NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE])

      @logger.log(Logger::DEBUG, 'Received new datafile and updated config. ' \
        "Old revision number: #{previous_revision}. New revision number: #{@config.revision}.")
    end
  end
end
