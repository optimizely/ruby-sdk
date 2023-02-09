# frozen_string_literal: true

#
#    Copyright 2019-2020, 2022-2023, Optimizely and contributors
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
require 'spec_helper'

describe Optimizely::HTTPProjectConfigManager do
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }

  before(:context) do
    VALID_SDK_KEY_CONFIG = OptimizelySpec::VALID_CONFIG_BODY.dup # rubocop:disable Lint/ConstantDefinitionInBlock
    VALID_SDK_KEY_CONFIG['accountId'] = '12002'
    VALID_SDK_KEY_CONFIG['revision'] = '81'
    VALID_SDK_KEY_CONFIG_JSON = JSON.dump(VALID_SDK_KEY_CONFIG) # rubocop:disable Lint/ConstantDefinitionInBlock
  end

  before(:example) do
    @http_project_config_manager = nil

    WebMock.reset_callbacks
    stub_request(:get, 'https://cdn.optimizely.com/datafiles/valid_sdk_key.json')
      .with(
        headers: {
          'Content-Type' => 'application/json'
        }
      )
      .to_return(status: 200, body: VALID_SDK_KEY_CONFIG_JSON, headers: {})

    stub_request(:get, 'https://cdn.optimizely.com/datafiles/invalid_sdk_key.json')
      .with(
        headers: {
          'Content-Type' => 'application/json'
        }
      )
      .to_return(status: [403, 'Forbidden'], body: '', headers: {})
  end

  after(:example) do
    @http_project_config_manager.stop! if @http_project_config_manager.instance_of? Optimizely::HTTPProjectConfigManager
  end

  describe '.project_config_manager' do
    it 'should get project config when valid url is given' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        url: 'https://cdn.optimizely.com/datafiles/valid_sdk_key.json'
      )

      sleep 0.1 until @http_project_config_manager.ready?
      expect(@http_project_config_manager.config).to be_a Optimizely::ProjectConfig
    end

    it 'should get project config when valid http url is given' do
      WebMock.reset!
      stub_request(:get, 'http://cdn.optimizely.com/datafiles/valid_sdk_key.json')
        .with(
          headers: {
            'Content-Type' => 'application/json'
          }
        )
        .to_return(status: 200, body: VALID_SDK_KEY_CONFIG_JSON, headers: {})

      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        url: 'http://cdn.optimizely.com/datafiles/valid_sdk_key.json'
      )

      sleep 0.1 until @http_project_config_manager.ready?
      expect(@http_project_config_manager.config).to be_a Optimizely::ProjectConfig
    end

    it 'should get project config when sdk_key is given' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key'
      )

      sleep 0.1 until @http_project_config_manager.ready?
      expect(@http_project_config_manager.config).to be_a Optimizely::ProjectConfig
    end

    it 'should get project config when sdk_key and valid url_template is given' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        url_template: 'https://cdn.optimizely.com/datafiles/%s.json'
      )
      sleep 0.1 until @http_project_config_manager.ready?

      expect(@http_project_config_manager.config).to be_a Optimizely::ProjectConfig
    end

    it 'should get instance ready immediately when datafile is provided' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile: config_body_JSON,
        start_by_default: false
      )
      # This expectation on main thread confirms that instance got ready immediately
      expect(@http_project_config_manager.ready?).to be true
    end

    it 'should wait to get project config upto blocking timeout when datafile is not provided' do
      # Add delay of 2 seconds in http response to the async thread.
      WebMock.after_request do |_request_signature, _response|
        sleep 2
      end

      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        start_by_default: false,
        blocking_timeout: 3
      )

      @http_project_config_manager.start!
      # This expectation would only pass if the .config call waits upto blocking timeout.
      expect(@http_project_config_manager.config).to be_a Optimizely::ProjectConfig
    end

    it 'should not wait more than blocking timeout to get project config when datafile is not provided' do
      # Add delay of 3 seconds in http response to the async thread.
      WebMock.after_request do |_request_signature, _response|
        sleep 3
      end

      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        start_by_default: false,
        blocking_timeout: 2
      )

      @http_project_config_manager.start!
      # This expectation would only pass if the .config call does not wait more than blocking timeout.
      expect(@http_project_config_manager.config).to be nil
    end

    it 'should send config update notification when project config is updated' do
      notification_center = Optimizely::NotificationCenter.new(Optimizely::NoOpLogger.new, error_handler)

      expect(notification_center).to receive(:send_notifications).with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE]
      ).once

      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        notification_center: notification_center
      )

      sleep 0.1 until @http_project_config_manager.ready?
    end

    it 'should not send config update notification when datafile is provided' do
      notification_center = Optimizely::NotificationCenter.new(Optimizely::NoOpLogger.new, error_handler)

      expect(notification_center).not_to receive(:send_notifications)

      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile: config_body_JSON,
        start_by_default: false,
        notification_center: notification_center
      )
      sleep 0.1 until @http_project_config_manager.ready?
    end
  end

  describe '.Initialize(sdk_key, datafile, auto_update: false)' do
    it 'should get project config instance' do
      logger = Optimizely::NoOpLogger.new
      datafile_project_config = Optimizely::DatafileProjectConfig.new(config_body_JSON, logger, error_handler)

      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile: config_body_JSON,
        auto_update: false,
        start_by_default: false,
        logger: logger,
        error_handler: error_handler
      )

      @http_project_config_manager.start!

      # All instance variables values of @http_project_config_manager
      @http_project_config_manager_arr = @http_project_config_manager.config.instance_variables.map do |attr|
        @http_project_config_manager.config.instance_variable_get attr
      end

      # All instance variables values of datafile_project_config
      datafile_project_config_arr = datafile_project_config.instance_variables.map do |attr|
        datafile_project_config.instance_variable_get attr
      end

      expect(@http_project_config_manager_arr).to eql(datafile_project_config_arr)
    end

    it 'should get instance ready immediately' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile: config_body_JSON,
        auto_update: false,
        start_by_default: false
      )
      expect(@http_project_config_manager.ready?).to be true
    end

    it 'should update config, send config update notification and does not schedule a future update' do
      notification_center = Optimizely::NotificationCenter.new(spy_logger, error_handler)

      datafile_project_config = Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler)

      expect(notification_center).to receive(:send_notifications).with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE]
      ).once

      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile: config_body_JSON,
        polling_interval: 0.1,
        auto_update: false,
        notification_center: notification_center,
        logger: spy_logger
      )

      # Sleep to ensure that new request is not scheduled.
      sleep 0.3

      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Fetching datafile from https://cdn.optimizely.com/datafiles/valid_sdk_key.json').once
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Datafile response status code 200').once
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Received new datafile and updated config. ' \
        'Old revision number: 42. New revision number: 81.').once

      # Asserts that config has updated from URL.
      expect(@http_project_config_manager.config.account_id).not_to eql(datafile_project_config.account_id)
    end
  end

  describe '.Initialize(sdk_key, datafile, auto_update: true)' do
    it 'should get project config instance' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile: config_body_JSON,
        start_by_default: false,
        logger: spy_logger,
        error_handler: error_handler
      )

      expect(@http_project_config_manager.config).not_to eq(nil)
    end

    it 'should get instance ready immediately' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile: config_body_JSON,
        start_by_default: false
      )
      expect(@http_project_config_manager.ready?).to be true
    end

    it 'should update config, send config update notification and schedules next call after previous timeout' do
      notification_center = Optimizely::NotificationCenter.new(spy_logger, error_handler)

      datafile_project_config = Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler)

      expect(notification_center).to receive(:send_notifications).with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE]
      ).once

      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile: config_body_JSON,
        polling_interval: 0.1,
        blocking_timeout: 2,
        notification_center: notification_center,
        logger: spy_logger
      )

      sleep 0.3

      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Fetching datafile from https://cdn.optimizely.com/datafiles/valid_sdk_key.json').at_least(2)

      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Received new datafile and updated config. ' \
        'Old revision number: 42. New revision number: 81.').once

      expect(@http_project_config_manager.config.account_id).not_to eql(datafile_project_config.account_id)
    end
  end

  describe '.Initialize(sdk_key, auto_update: true)' do
    it 'should fetch project config with default datafile url' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key'
      )
      sleep 0.1 until @http_project_config_manager.ready?
      expect(@http_project_config_manager.config).to be_a Optimizely::ProjectConfig
    end

    it 'should fetch datafile url and get instance ready' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        start_by_default: false
      )

      expect(@http_project_config_manager.ready?).to be false

      @http_project_config_manager.start!

      sleep 0.1 until @http_project_config_manager.ready?

      expect(@http_project_config_manager.ready?).to be true
    end

    it 'should not update project config when response body is not valid json' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'invalid_sdk_key',
        start_by_default: false,
        polling_interval: 1,
        blocking_timeout: 5
      )
      @http_project_config_manager.start!
      expect(@http_project_config_manager.config).to eq(nil)
    end
  end

  describe '#get_datafile_url' do
    it 'should log an error when both sdk key and url are nil' do
      expect do
        @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
          sdk_key: nil,
          url: nil,
          error_handler: error_handler,
          logger: spy_logger
        )
      end.to raise_error(Optimizely::InvalidInputsError, 'Must provide at least one of sdk_key or url.')

      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Must provide at least one of sdk_key or url.')
    end

    it 'should log an error when invalid url_template is given' do
      expect do
        @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
          sdk_key: 'valid_sdk_key',
          url_template: 'https://cdn.optimizely.com/datafiles/%d.json',
          error_handler: error_handler,
          logger: spy_logger
        )
      end.to raise_error(Optimizely::InvalidInputsError, 'Invalid url_template https://cdn.optimizely.com/datafiles/%d.json provided.')

      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Invalid url_template https://cdn.optimizely.com/datafiles/%d.json provided.')
    end

    it 'Should log failure message with status code when failed to fetch datafile' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        url: 'https://cdn.optimizely.com/datafiles/invalid_sdk_key.json',
        sdk_key: 'valid_sdk_key',
        datafile_access_token: 'the-token',
        logger: spy_logger
      )
      sleep 0.1
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Datafile fetch failed, status: 403, message: Forbidden').once
    end
  end

  describe '.polling_interval' do
    it 'should set default and log an error when polling_interval is nil' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'sdk_key',
        url: nil,
        polling_interval: nil,
        blocking_timeout: 5,
        error_handler: error_handler,
        logger: spy_logger
      )

      expect(@http_project_config_manager.instance_variable_get(:@polling_interval)).to eq(300)
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, 'Polling interval is not provided. Defaulting to 300 seconds.')
    end

    it 'should set default and log an error when polling_interval has invalid type' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'sdk_key',
        url: nil,
        polling_interval: true,
        blocking_timeout: 5,
        error_handler: error_handler,
        logger: spy_logger
      )

      expect(@http_project_config_manager.instance_variable_get(:@polling_interval)).to eq(300)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Polling interval 'true' has invalid type. Defaulting to 300 seconds.")
    end

    it 'should set default and log an error when polling_interval has invalid range' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'sdk_key',
        url: nil,
        polling_interval: 999_999_999_999_999_999,
        blocking_timeout: 5,
        error_handler: error_handler,
        logger: spy_logger
      )

      expect(@http_project_config_manager.instance_variable_get(:@polling_interval)).to eq(300)
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, "Polling interval '999999999999999999' has invalid range. Defaulting to 300 seconds.")
    end
  end

  describe '.blocking_timeout' do
    it 'should set default and log an error when blocking_timeout is nil' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'sdk_key',
        url: nil,
        polling_interval: 5,
        blocking_timeout: nil,
        error_handler: error_handler,
        logger: spy_logger
      )

      expect(@http_project_config_manager.instance_variable_get(:@blocking_timeout)).to eq(15)
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, 'Blocking timeout is not provided. Defaulting to 15 seconds.')
    end

    it 'should set default and log an error when blocking_timeout has invalid type' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'sdk_key',
        url: nil,
        polling_interval: 5,
        blocking_timeout: true,
        error_handler: error_handler,
        logger: spy_logger
      )

      expect(@http_project_config_manager.instance_variable_get(:@blocking_timeout)).to eq(15)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Blocking timeout 'true' has invalid type. Defaulting to 15 seconds.")
    end

    it 'should set default and log an error when blocking_timeout has invalid range' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'sdk_key',
        url: nil,
        polling_interval: 5,
        blocking_timeout: 999_999_999_999_999_999,
        error_handler: error_handler,
        logger: spy_logger
      )

      expect(@http_project_config_manager.instance_variable_get(:@blocking_timeout)).to eq(15)
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, "Blocking timeout '999999999999999999' has invalid range. Defaulting to 15 seconds.")
    end
  end

  describe 'optimizely_config' do
    it 'optimizely_config object updates correctly when new config is recieved' do
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile: config_body_JSON,
        polling_interval: 0.1
      )
      expect(@http_project_config_manager.optimizely_config['revision']).to eq('42')
      sleep 0.5
      expect(@http_project_config_manager.optimizely_config['revision']).to eq('81')
    end
  end

  describe 'datafile authentication' do
    it 'should add authorization header when auth token is provided' do
      allow(Optimizely::Helpers::HttpUtils).to receive(:make_request)
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile_access_token: 'the-token'
      )
      sleep 0.1
      expect(Optimizely::Helpers::HttpUtils).to have_received(:make_request).with(anything, anything, anything, hash_including('Authorization' => 'Bearer the-token'), anything, anything)
    end

    it 'should use authenticated datafile url when auth token is provided' do
      allow(Optimizely::Helpers::HttpUtils).to receive(:make_request).and_return(VALID_SDK_KEY_CONFIG_JSON)
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile_access_token: 'the-token'
      )
      sleep 0.1
      expect(Optimizely::Helpers::HttpUtils).to have_received(:make_request).with('https://config.optimizely.com/datafiles/auth/valid_sdk_key.json', any_args)
    end

    it 'should use public datafile url when auth token is not provided' do
      allow(Optimizely::Helpers::HttpUtils).to receive(:make_request).and_return(VALID_SDK_KEY_CONFIG_JSON)
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key'
      )
      sleep 0.1
      expect(Optimizely::Helpers::HttpUtils).to have_received(:make_request).with('https://cdn.optimizely.com/datafiles/valid_sdk_key.json', any_args)
    end

    it 'should prefer user provided template url over defaults' do
      allow(Optimizely::Helpers::HttpUtils).to receive(:make_request).and_return(VALID_SDK_KEY_CONFIG_JSON)
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile_access_token: 'the-token',
        url_template: 'http://awesomeurl'
      )
      sleep 0.1
      expect(Optimizely::Helpers::HttpUtils).to have_received(:make_request).with('http://awesomeurl', any_args)
    end

    it 'should hide access token when printing logs' do
      allow(Optimizely::Helpers::HttpUtils).to receive(:make_request)
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile_access_token: 'the-token',
        logger: spy_logger
      )
      sleep 0.1
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Datafile request headers: {"Content-Type"=>"application/json", "Authorization"=>"********"}').once
    end

    it 'should pass the proxy config that is passed in' do
      proxy_config = double(:proxy_config)

      allow(Optimizely::Helpers::HttpUtils).to receive(:make_request)
      @http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'valid_sdk_key',
        datafile_access_token: 'the-token',
        proxy_config: proxy_config
      )
      sleep 0.1
      expect(Optimizely::Helpers::HttpUtils).to have_received(:make_request).with(anything, anything, anything, hash_including('Authorization' => 'Bearer the-token'), anything, proxy_config)
    end
  end
end
