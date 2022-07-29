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
require 'optimizely'
require 'optimizely/config_manager/http_project_config_manager'
require 'optimizely/config_manager/static_project_config_manager'
require 'optimizely/exceptions'
require 'optimizely/optimizely_factory'

describe Optimizely::OptimizelyFactory do
  let(:datafile) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:user_profile_service) { spy('user_profile_service') }
  let(:event_dispatcher) { Optimizely::EventDispatcher.new }
  let(:notification_center) { Optimizely::NotificationCenter.new(spy_logger, error_handler) }

  before(:example) do
    WebMock.allow_net_connect!
    stub_request(:get, 'https://cdn.optimizely.com/datafiles/sdk_key.json')
      .with(
        headers: {
          'Content-Type' => 'application/json'
        }
      )
      .to_return(status: 200, body: '', headers: {})
  end

  describe '.default_instance' do
    it 'should create http config manager when sdk_key is given' do
      optimizely_instance = Optimizely::OptimizelyFactory.default_instance('sdk_key', datafile)
      expect(optimizely_instance.config_manager).to be_instance_of(Optimizely::HTTPProjectConfigManager)
    end

    it 'should create http config manager when polling interval and blocking timeout are set' do
      Optimizely::OptimizelyFactory.polling_interval(40)
      Optimizely::OptimizelyFactory.blocking_timeout(5)
      optimizely_instance = Optimizely::OptimizelyFactory.default_instance('sdk_key', datafile)

      # Verify that values set in OptimizelyFactory are being used inside config manager.
      expect(optimizely_instance.config_manager.instance_variable_get(:@polling_interval)).to eq(40)
      expect(optimizely_instance.config_manager.instance_variable_get(:@blocking_timeout)).to eq(5)
    end

    it 'should create http config manager with the same components as the instance' do
      optimizely_instance = Optimizely::OptimizelyFactory.default_instance('sdk_key', datafile)
      expect(optimizely_instance.error_handler).to be(optimizely_instance.config_manager.instance_variable_get(:@error_handler))
      expect(optimizely_instance.logger).to be(optimizely_instance.config_manager.instance_variable_get(:@logger))
      expect(optimizely_instance.notification_center).to be(optimizely_instance.config_manager.instance_variable_get(:@notification_center))
    end
  end

  describe '.default_instance_with_manager' do
    it 'should take provided custom config manager' do
      class CustomConfigManager # rubocop:disable Lint/ConstantDefinitionInBlock, Lint/UnneededCopDisableDirective, Lint/RedundantCopDisableDirective
        attr_reader :config
      end

      custom_config_manager = CustomConfigManager.new
      optimizely_instance = Optimizely::OptimizelyFactory.default_instance_with_config_manager(custom_config_manager)
      expect(optimizely_instance.config_manager).to be(custom_config_manager)
    end
  end

  describe '.custom_instance' do
    it 'should take http config manager when sdk key, polling interval, blocking timeout are given' do
      Optimizely::OptimizelyFactory.polling_interval(50)
      Optimizely::OptimizelyFactory.blocking_timeout(10)
      optimizely_instance = Optimizely::OptimizelyFactory.custom_instance(
        'sdk_key',
        datafile,
        event_dispatcher,
        Optimizely::NoOpLogger.new,
        error_handler,
        false,
        user_profile_service,
        nil,
        notification_center
      )

      # Verify that values set in OptimizelyFactory are being used inside config manager.
      expect(optimizely_instance.config_manager.instance_variable_get(:@polling_interval)).to eq(50)
      expect(optimizely_instance.config_manager.instance_variable_get(:@blocking_timeout)).to eq(10)
    end

    it 'should take event processor when flush interval and batch size are set' do
      Optimizely::OptimizelyFactory.max_event_flush_interval(5)
      Optimizely::OptimizelyFactory.max_event_batch_size(100)

      optimizely_instance = Optimizely::OptimizelyFactory.custom_instance('sdk_key')

      expect(optimizely_instance.event_processor.flush_interval).to eq(5)
      expect(optimizely_instance.event_processor.batch_size).to eq(100)
      optimizely_instance.close
    end

    it 'should assign passed components to both the instance and http manager' do
      logger = Optimizely::NoOpLogger.new
      optimizely_instance = Optimizely::OptimizelyFactory.custom_instance(
        'sdk_key',
        datafile,
        event_dispatcher,
        logger,
        error_handler,
        false,
        user_profile_service,
        nil,
        notification_center
      )

      expect(error_handler).to be(optimizely_instance.config_manager.instance_variable_get(:@error_handler))
      expect(logger).to be(optimizely_instance.config_manager.instance_variable_get(:@logger))
      expect(notification_center).to be(optimizely_instance.config_manager.instance_variable_get(:@notification_center))

      expect(error_handler).to be(optimizely_instance.error_handler)
      expect(logger).to be(optimizely_instance.logger)
      expect(notification_center).to be(optimizely_instance.notification_center)
    end
  end

  describe '.max_event_batch_size' do
    it 'should log error message and return nil when invalid batch size provided' do
      expect(Optimizely::OptimizelyFactory.max_event_batch_size([], spy_logger)).to eq(nil)
      expect(Optimizely::OptimizelyFactory.max_event_batch_size(true, spy_logger)).to eq(nil)
      expect(Optimizely::OptimizelyFactory.max_event_batch_size('test', spy_logger)).to eq(nil)
      expect(Optimizely::OptimizelyFactory.max_event_batch_size(5.2, spy_logger)).to eq(nil)
      expect(Optimizely::OptimizelyFactory.max_event_batch_size(nil, spy_logger)).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Batch size is invalid, setting to default batch size 10.').exactly(5).times
      expect(Optimizely::OptimizelyFactory.max_event_batch_size(0, spy_logger)).to eq(nil)
      expect(Optimizely::OptimizelyFactory.max_event_batch_size(-2, spy_logger)).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Batch size is negative, setting to default batch size 10.').twice
    end

    it 'should not log error and return batch size and when valid batch size provided' do
      expect(Optimizely::OptimizelyFactory.max_event_batch_size(5, spy_logger)).to eq(5)
      expect(spy_logger).not_to have_received(:log)
    end
  end

  describe '.max_event_flush_interval' do
    it 'should log error message and return nil when invalid flush interval provided' do
      expect(Optimizely::OptimizelyFactory.max_event_flush_interval([], spy_logger)).to eq(nil)
      expect(Optimizely::OptimizelyFactory.max_event_flush_interval(true, spy_logger)).to eq(nil)
      expect(Optimizely::OptimizelyFactory.max_event_flush_interval('test', spy_logger)).to eq(nil)
      expect(Optimizely::OptimizelyFactory.max_event_flush_interval(nil, spy_logger)).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Flush interval is invalid, setting to default flush interval 30000.').exactly(4).times
      expect(Optimizely::OptimizelyFactory.max_event_flush_interval(0, spy_logger)).to eq(nil)
      expect(Optimizely::OptimizelyFactory.max_event_flush_interval(-2, spy_logger)).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Flush interval is negative, setting to default flush interval 30000.').twice
    end

    it 'should not log error and return batch size and when valid flush interval provided' do
      expect(Optimizely::OptimizelyFactory.max_event_flush_interval(5, spy_logger)).to eq(5)
      expect(Optimizely::OptimizelyFactory.max_event_flush_interval(5.5, spy_logger)).to eq(5.5)
      expect(spy_logger).not_to have_received(:log)
    end
  end
end
