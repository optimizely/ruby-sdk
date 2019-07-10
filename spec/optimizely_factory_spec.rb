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

  describe '.initialize' do
    it 'should take static project config manager when sdk_key and config manager are not given' do
      allow(Optimizely::StaticProjectConfigManager).to receive(:new)
      static_project_config_manager = Optimizely::StaticProjectConfigManager.new(datafile, spy_logger, error_handler, false)
      instance_with_config_manager = Optimizely::OptimizelyFactory.initialize(
        datafile,
        event_dispatcher,
        spy_logger,
        error_handler,
        false,
        user_profile_service,
        nil,
        nil,
        notification_center
      )
      expect(instance_with_config_manager.config_manager). to eq(static_project_config_manager)
    end
  end

  describe '.initialize_optimizely_with_config_manager' do
    it 'should take provided custom config manager' do
      class CustomConfigManager
        def get_config; end
      end

      custom_config_manager = CustomConfigManager.new
      instance_with_config_manager = Optimizely::OptimizelyFactory.initialize_optimizely_with_config_manager(
        datafile,
        event_dispatcher,
        spy_logger,
        error_handler,
        false,
        user_profile_service,
        custom_config_manager,
        notification_center
      )
      expect(instance_with_config_manager.config_manager). to eq(custom_config_manager)
    end
  end

  describe '.initialize_optimizely_with_sdk_key' do
    it 'should take http config manager' do
      allow(Optimizely::HTTPProjectConfigManager).to receive(:new)

      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: 'sdk_key',
        datafile: datafile,
        logger: spy_logger,
        error_handler: error_handler,
        skip_json_validation: false,
        notification_center: notification_center
      )

      instance_with_config_manager = Optimizely::OptimizelyFactory.initialize_optimizely_with_sdk_key(
        datafile,
        spy_logger,
        event_dispatcher,
        error_handler,
        false,
        user_profile_service,
        'sdk_key',
        notification_center
      )

      expect(instance_with_config_manager.config_manager). to eq(http_project_config_manager)
    end
  end
end
