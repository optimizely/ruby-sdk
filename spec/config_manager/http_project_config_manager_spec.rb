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
require 'spec_helper'
require 'optimizely/config_manager/http_project_config_manager'
require 'optimizely/exceptions'
require 'optimizely/error_handler'
require 'optimizely/helpers/constants'
require 'optimizely/helpers/validator'
require 'optimizely/logger'
describe Optimizely::HTTPProjectConfigManager do
  WebMock.allow_net_connect!
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }

  describe '.project_config_manager' do
    it 'should get project config when valid url is given' do
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        url: 'https://cdn.optimizely.com/datafiles/QBw9gFM8oTn7ogY9ANCC1z.json'
      )

      until http_project_config_manager.ready?; end
      expect(http_project_config_manager.get_config).not_to eq(nil)
    end

    it 'should get project config when sdk_key is given' do
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z'
      )

      until http_project_config_manager.ready?; end
      expect(http_project_config_manager.get_config).not_to eq(nil)
    end

    it 'should get project config when sdk_key and valid url_template is given' do
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        url_template: 'https://cdn.optimizely.com/datafiles/%s.json'
      )
      until http_project_config_manager.ready?; end

      expect(http_project_config_manager.get_config).not_to eq(nil)
    end

    it 'should get instance ready immediately when datafile is provided' do
      start = Time.now
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        datafile: config_body_JSON,
        start_by_default: false
      )
      until http_project_config_manager.ready?; end
      finish = Time.now
      expect(finish - start).to be < 1
    end

    it 'should wait to get project config when datafile is not provided' do
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        start_by_default: false
      )
      start = Time.now
      http_project_config_manager.start!
      until http_project_config_manager.ready?; end
      finish = Time.now
      expect(finish - start).to be > 0
      expect(http_project_config_manager.get_config).not_to eq(nil)
    end

    it 'should send config update notification when project config is updated' do
      notification_center = Optimizely::NotificationCenter.new(spy_logger, error_handler)

      expect(notification_center).to receive(:send_notifications).with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE]
      ).once

      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        notification_center: notification_center
      )

      until http_project_config_manager.ready?; end
      expect(http_project_config_manager.get_config).not_to eq(nil)
    end

    it 'should not send config update notification when datafile is provided' do
      notification_center = Optimizely::NotificationCenter.new(spy_logger, error_handler)

      expect(notification_center).not_to receive(:send_notifications)

      Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        datafile: config_body_JSON,
        start_by_default: false,
        notification_center: notification_center
      )
    end
  end

  describe '.Initialize(sdk_key, datafile, auto_update: false)' do
    it 'should get project config instance' do
      datafile_project_config = Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler)

      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        datafile: config_body_JSON,
        auto_update: false,
        start_by_default: false,
        logger: spy_logger,
        error_handler: error_handler
      )

      http_project_config_manager.start!

      # All instance variables values of http_project_config_manager
      http_project_config_manager_arr = http_project_config_manager.get_config.instance_variables.map do |attr|
        http_project_config_manager.get_config.instance_variable_get attr
      end

      # All instance variables values of datafile_project_config
      datafile_project_config_arr = datafile_project_config.instance_variables.map do |attr|
        datafile_project_config.instance_variable_get attr
      end

      expect(http_project_config_manager_arr).to eql(datafile_project_config_arr)
    end

    it 'should get instance ready immediately' do
      start = Time.now
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        datafile: config_body_JSON,
        auto_update: false,
        start_by_default: false
      )
      expect(http_project_config_manager.get_config).not_to eq(nil)
      finish = Time.now
      expect(finish - start).to be < 1
    end

    it 'should update config, send config update notification and does not schedule a future update' do
      notification_center = Optimizely::NotificationCenter.new(spy_logger, error_handler)

      datafile_project_config = Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler)

      expect(notification_center).to receive(:send_notifications).with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE]
      ).once

      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        datafile: config_body_JSON,
        polling_interval: 1,
        auto_update: false,
        notification_center: notification_center,
        logger: spy_logger
      )

      # Sleep to ensure that new request is not scheduled.
      sleep 3

      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Fetching datafile from https://cdn.optimizely.com/datafiles/QBw9gFM8oTn7ogY9ANCC1z.json').once

      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Received new datafile and updated config. ' \
        'Old revision number: 42. New revision number: 81.').once

      # Asserts that config has updated from URL.
      expect(http_project_config_manager.get_config.account_id).not_to eql(datafile_project_config.account_id)
    end
  end

  describe '.Initialize(sdk_key, datafile, auto_update: true)' do
    it 'should get project config instance' do
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        datafile: config_body_JSON,
        start_by_default: false,
        logger: spy_logger,
        error_handler: error_handler
      )

      expect(http_project_config_manager.get_config).not_to eq(nil)
    end

    it 'should get instance ready immediately' do
      start = Time.now
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        datafile: config_body_JSON,
        start_by_default: false
      )

      expect(http_project_config_manager.ready?).to be true
      finish = Time.now
      expect(finish - start).to be < 1
    end

    it 'should update config, send config update notification and schedules next call after previous timeout' do
      notification_center = Optimizely::NotificationCenter.new(spy_logger, error_handler)

      datafile_project_config = Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler)

      expect(notification_center).to receive(:send_notifications).with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE]
      ).once

      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        datafile: config_body_JSON,
        polling_interval: 1,
        notification_center: notification_center,
        logger: spy_logger
      )

      sleep 4

      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Fetching datafile from https://cdn.optimizely.com/datafiles/QBw9gFM8oTn7ogY9ANCC1z.json').at_least(2)

      expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'Received new datafile and updated config. ' \
        'Old revision number: 42. New revision number: 81.').once

      expect(http_project_config_manager.get_config.account_id).not_to eql(datafile_project_config.account_id)
    end
  end

  describe '.Initialize(sdk_key, auto_update: true)' do
    it 'should fetch project config with default datafile url' do
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z'
      )

      expect(http_project_config_manager.get_config).not_to eq(nil)
    end

    it 'should fetch datafile url and get instance ready' do
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'QBw9gFM8oTn7ogY9ANCC1z',
        start_by_default: false
      )

      expect(http_project_config_manager.ready?).to be false

      http_project_config_manager.start!

      until http_project_config_manager.ready?; end

      expect(http_project_config_manager.ready?).to be true
    end

    it 'should not update project config when response body is not valid json' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'invalid_sdk',
        start_by_default: false,
        polling_interval: 1,
        blocking_timeout: 5
      )
      http_project_config_manager.start!
      expect(http_project_config_manager.get_config).to eq(nil)
    end
  end

  describe '#get_datafile_url' do
    it 'should log an error when both sdk key and url are nil' do
      expect(error_handler).to receive(:handle_error).once.with(Optimizely::InvalidInputsError)

      Optimizely::HTTPProjectConfigManager.new(
        sdk_key: nil,
        url: nil,
        error_handler: error_handler,
        logger: spy_logger
      )
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Must provide at least one of sdk_key or url.')
    end
  end
end
