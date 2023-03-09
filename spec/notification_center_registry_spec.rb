# frozen_string_literal: true

#
#    Copyright 2017-2019, 2022-2023, Optimizely and contributors
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
require 'spec_helper'
require 'optimizely/error_handler'
require 'optimizely/event_builder'
require 'optimizely/exceptions'
require 'optimizely/logger'
require 'optimizely/notification_center'
require 'optimizely/notification_center_registry'
describe Optimizely::NotificationCenter do
  let(:spy_logger) { spy('logger') }
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:logger) { Optimizely::NoOpLogger.new }
  let(:notification_center) { Optimizely::NotificationCenter.new(spy_logger, error_handler) }

  describe '#NotificationCenterRegistry' do
    describe 'test get notification center' do
      it 'should log error with no sdk_key' do
        Optimizely::NotificationCenterRegistry.get_notification_center(nil, spy_logger)
        expect(spy_logger).to have_received(:log).with(Logger::ERROR, "#{Optimizely::MissingSdkKeyError.new.message} ODP may not work properly without it.")
      end

      it 'should return notification center with odp callback' do
        sdk_key = 'VALID'
        stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
          .to_return(status: 200, body: config_body_JSON)

        project = Optimizely::Project.new(nil, nil, spy_logger, nil, false, nil, sdk_key)

        notification_center = Optimizely::NotificationCenterRegistry.get_notification_center(sdk_key, spy_logger)
        expect(notification_center).to be_a Optimizely::NotificationCenter

        config_notifications = notification_center.instance_variable_get('@notifications')[Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE]]
        expect(config_notifications).to include({notification_id: anything, callback: project.method(:update_odp_config_on_datafile_update)})
        expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)

        project.close
      end

      it 'should only create one notification center per sdk_key' do
        sdk_key = 'single'
        stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
          .to_return(status: 200, body: config_body_JSON)

        notification_center = Optimizely::NotificationCenterRegistry.get_notification_center(sdk_key, spy_logger)
        project = Optimizely::Project.new(nil, nil, spy_logger, nil, false, nil, sdk_key)

        expect(notification_center).to eq(Optimizely::NotificationCenterRegistry.get_notification_center(sdk_key, spy_logger))
        expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)

        project.close
      end
    end

    describe 'test remove notification center' do
      it 'should remove notification center and callbacks' do
        sdk_key = 'segments-test'
        stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
          .to_return(status: 200, body: config_body_JSON)

        notification_center = Optimizely::NotificationCenterRegistry.get_notification_center(sdk_key, spy_logger)
        expect(notification_center).to receive(:send_notifications).once

        project = Optimizely::Project.new(nil, nil, spy_logger, nil, false, nil, sdk_key)
        project.config_manager.config

        Optimizely::NotificationCenterRegistry.remove_notification_center(sdk_key)
        expect(Optimizely::NotificationCenterRegistry.instance_variable_get('@notification_centers').values).not_to include(notification_center)

        revised_datafile = config_body.dup
        revised_datafile['revision'] = (revised_datafile['revision'].to_i + 1).to_s
        revised_datafile = Optimizely::DatafileProjectConfig.create(JSON.dump(revised_datafile), spy_logger, nil, nil)

        # trigger notification
        project.config_manager.send(:set_config, revised_datafile)
        expect(notification_center).not_to receive(:send_notifications)
        expect(notification_center).not_to eq(Optimizely::NotificationCenterRegistry.get_notification_center(sdk_key, spy_logger))

        expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)

        project.close
      end
    end
  end
end
