# frozen_string_literal: true

#
#    Copyright 2019-2020, Optimizely and contributors
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
require_relative '../helpers/network_utils'
require_relative '../logger'
require_relative '../notification_center'
require_relative '../project_config'
require_relative '../optimizely_config'
require_relative 'project_config_manager'
require_relative 'async_scheduler'

require 'json'

module Optimizely
  class HTTPProjectConfigManager < ProjectConfigManager
    # Config manager that polls for the datafile and updated ProjectConfig based on an update interval.

    attr_reader :stopped, :optimizely_config

    # Initialize config manager. One of sdk_key or url has to be set to be able to use.
    #
    # sdk_key - Optional string uniquely identifying the datafile. It's required unless a URL is passed in.
    # datafile: Optional JSON string representing the project.
    # polling_interval - Optional floating point number representing time interval in seconds
    #                  at which to request datafile and set ProjectConfig.
    # blocking_timeout - Optional Time in seconds to block the config call until config object has been initialized.
    # auto_update - Boolean indicates to run infinitely or only once.
    # start_by_default - Boolean indicates to start by default AsyncScheduler.
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
      @skip_json_validation = skip_json_validation
      @notification_center = notification_center.is_a?(Optimizely::NotificationCenter) ? notification_center : NotificationCenter.new(@logger, @error_handler)
      @config = datafile.nil? ? nil : DatafileProjectConfig.create(datafile, @logger, @error_handler, @skip_json_validation)
      @optimizely_config = @config.nil? ? nil : OptimizelyConfig.new(@config).config
      @mutex = Mutex.new
      @resource = ConditionVariable.new
      @async_scheduler = AsyncScheduler.new(method(:fetch_datafile_config), @polling_interval, auto_update, @logger)
      # Start async scheduler in the end to avoid race condition where scheduler executes
      # callback which makes use of variables not yet initialized by the main thread.
      @async_scheduler.start! if start_by_default == true
      @stopped = false
    end

    def ready?
      !@config.nil?
    end

    def start!
      if @stopped
        @logger.log(Logger::WARN, 'Not starting. Already stopped.')
        return
      end

      @async_scheduler.start!
      @stopped = false
    end

    def stop!
      if @stopped
        @logger.log(Logger::WARN, 'Not pausing. Manager has not been started.')
        return
      end

      @async_scheduler.stop!
      @config = nil
      @stopped = true
    end

    def config
      # Get Project Config.

      # if stopped is true, then simply return @config.
      # If the background datafile polling thread is running. and config has been initalized,
      # we simply return @config.
      # If it is not, we wait and block maximum for @blocking_timeout.
      # If thread is not running, we fetch the datafile and update config.
      return @config if @stopped

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
        headers = {}
        headers['Content-Type'] = 'application/json'
        headers['If-Modified-Since'] = @last_modified if @last_modified

        response = Helpers::NetworkUtils.make_request(
          @datafile_url, :get, nil, headers, Helpers::Constants::CONFIG_MANAGER['REQUEST_TIMEOUT']
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
      @optimizely_config = OptimizelyConfig.new(config).config

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
          "Polling interval is not provided. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']} seconds."
        )
        @polling_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']
        return
      end

      unless polling_interval.is_a? Numeric
        @logger.log(
          Logger::ERROR,
          "Polling interval '#{polling_interval}' has invalid type. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']} seconds."
        )
        @polling_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']
        return
      end

      unless polling_interval.positive? && polling_interval <= Helpers::Constants::CONFIG_MANAGER['MAX_SECONDS_LIMIT']
        @logger.log(
          Logger::DEBUG,
          "Polling interval '#{polling_interval}' has invalid range. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']} seconds."
        )
        @polling_interval = Helpers::Constants::CONFIG_MANAGER['DEFAULT_UPDATE_INTERVAL']
        return
      end

      @polling_interval = polling_interval
    end

    def blocking_timeout(blocking_timeout)
      # Sets time in seconds to block the config call until config has been initialized.
      #
      # blocking_timeout - Time in seconds to block the config call.

      # If valid set given timeout, default blocking_timeout otherwise.

      if blocking_timeout.nil?
        @logger.log(
          Logger::DEBUG,
          "Blocking timeout is not provided. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']} seconds."
        )
        @blocking_timeout = Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']
        return
      end

      unless blocking_timeout.is_a? Integer
        @logger.log(
          Logger::ERROR,
          "Blocking timeout '#{blocking_timeout}' has invalid type. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']} seconds."
        )
        @blocking_timeout = Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']
        return
      end

      unless blocking_timeout.between?(Helpers::Constants::CONFIG_MANAGER['MIN_SECONDS_LIMIT'], Helpers::Constants::CONFIG_MANAGER['MAX_SECONDS_LIMIT'])
        @logger.log(
          Logger::DEBUG,
          "Blocking timeout '#{blocking_timeout}' has invalid range. Defaulting to #{Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']} seconds."
        )
        @blocking_timeout = Helpers::Constants::CONFIG_MANAGER['DEFAULT_BLOCKING_TIMEOUT']
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
        error_msg = 'Must provide at least one of sdk_key or url.'
        @logger.log(Logger::ERROR, error_msg)
        @error_handler.handle_error(InvalidInputsError.new(error_msg))
      end

      unless url
        url_template ||= Helpers::Constants::CONFIG_MANAGER['DATAFILE_URL_TEMPLATE']
        begin
          return (url_template % sdk_key)
        rescue
          error_msg = "Invalid url_template #{url_template} provided."
          @logger.log(Logger::ERROR, error_msg)
          @error_handler.handle_error(InvalidInputsError.new(error_msg))
        end
      end

      url
    end
  end
end
