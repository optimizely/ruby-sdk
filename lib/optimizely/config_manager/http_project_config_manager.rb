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
      @blocking_timeout = nil
      blocking_timeout(blocking_timeout)
      @last_modified = nil
      @async_scheduler = AsyncScheduler.new(method(:fetch_datafile_config), @polling_interval, auto_update, @logger)
      @async_scheduler.start! if start_by_default == true
      @skip_json_validation = skip_json_validation
      @notification_center = notification_center.is_a?(Optimizely::NotificationCenter) ? notification_center : NotificationCenter.new(@logger, @error_handler)
      @config = datafile.nil? ? nil : DatafileProjectConfig.create(datafile, @logger, @error_handler, @skip_json_validation)
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

      # If the background datafile polling thread is running. and config has been initalized,
      # we simply return config.
      # If it is not, we wait and block maximum for @blocking_timeout.
      # If thread is not running, we fetch the datafile and update config.
      if @async_scheduler.running
        return @config if ready?

        @mutex.synchronize do
          @resource.wait(@mutex, @blocking_timeout)
          return @config
        end
      end

      fetch_datafile_config
      @config
    end

    private

    def fetch_datafile_config
      # Fetch datafile, handle response and send notification on config update.
      config = request_config
      return unless config

      set_config config
    end

    def request_config
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
        return nil
      end

      # Leave datafile and config unchanged if it has not been modified.
      if response.code == '304'
        @logger.log(
          Logger::DEBUG,
          "Not updating config as datafile has not updated since #{@last_modified}."
        )
        return
      end

      @last_modified = response[Helpers::Constants::HTTP_HEADERS['LAST_MODIFIED']]

      config = DatafileProjectConfig.create(response.body, @logger, @error_handler, @skip_json_validation) if response.body

      config
    end

    def set_config(config)
      # Send notification if project config is updated.
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

    def polling_interval(polling_interval)
      # Sets frequency at which datafile has to be polled and ProjectConfig updated.
      #
      # polling_interval - Time in seconds after which to update datafile.

      # If valid set given polling interval, default update interval otherwise.

      if polling_interval.nil?
        @logger.log(
          Logger::DEBUG,
          "Polling interval is not given. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']}."
        )
        @polling_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']
        return
      end

      unless polling_interval.is_a? Integer
        @logger.log(
          Logger::DEBUG,
          "Polling interval '#{polling_interval}' has invalid type. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']}."
        )
        @polling_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']
        return
      end

      unless polling_interval.between?(Helpers::Constants::CONFIG_MANAGER['MIN_SECONDS_LIMIT'], Helpers::Constants::CONFIG_MANAGER['MAX_SECONDS_LIMIT'])
        @logger.log(
          Logger::DEBUG,
          "Polling interval '#{polling_interval}' has invalid range. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']}."
        )
        @polling_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']
        return
      end

      @polling_interval = polling_interval
    end

    def blocking_timeout(blocking_timeout)
      # Sets time in seconds to block the get_config call until config has been initialized.
      #
      # blocking_timeout - Time in seconds after which to update datafile.

      # If valid set given timeout, default blocking_timeout otherwise.

      if blocking_timeout.nil?
        @logger.log(
          Logger::DEBUG,
          "Blocking timeout is not given. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']}."
        )
        @polling_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']
        return
      end

      unless blocking_timeout.is_a? Integer
        @logger.log(
          Logger::DEBUG,
          "Blocking timeout '#{blocking_timeout}' has invalid type. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']}."
        )
        @polling_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']
        return
      end

      unless blocking_timeout.between?(Helpers::Constants::CONFIG_MANAGER['MIN_SECONDS_LIMIT'], Helpers::Constants::CONFIG_MANAGER['MAX_SECONDS_LIMIT'])
        @logger.log(
          Logger::DEBUG,
          "Blocking timeout '#{blocking_timeout}' has invalid range. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']}."
        )
        @polling_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']
        return
      end

      @blocking_timeout = blocking_timeout
    end

    def get_datafile_url(sdk_key, url, url_template)
      # Determines URL from where to fetch the datafile.
      # sdk_key - Key uniquely identifying the datafile.
      # url - String representing URL from which to fetch the datafile.
      # url_template - String representing template which is filled in with
      #               SDK key to determine URL from which to fetch the datafile.
      # Returns String representing URL to fetch datafile from.
      if sdk_key.nil? && url.nil?
        @logger.log(Logger::ERROR, 'Must provide at least one of sdk_key or url.')
        @error_handler.handle_error(InvalidInputsError)
      end

      unless url
        url_template ||= Helpers::Constants::CONFIG_MANAGER['DATAFILE_URL_TEMPLATE']
        begin
          return (url_template % sdk_key)
        rescue
          @logger.log(Logger::ERROR, "Invalid url_template #{url_template} provided.")
          @error_handler.handle_error(InvalidInputsError)
        end
      end

      url
    end
  end
end
