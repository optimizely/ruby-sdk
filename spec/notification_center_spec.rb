# frozen_string_literal: true

#
#    Copyright 2017, Optimizely and contributors
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
require 'optimizely/logger'
require 'optimizely/notification_center'
describe Optimizely::NotificationCenter do
  let(:spy_logger) { spy('logger') }
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:logger) { Optimizely::NoOpLogger.new }
  let(:notification_center) { Optimizely::NotificationCenter.new(spy_logger, error_handler) }

  before(:context) do
    class CallBack
      def call(args)
        args
      end
    end

    @callback = CallBack.new
    @callback_reference = @callback.method(:call)
  end

  describe '#Notification center' do
    describe 'test add notification with invalid params' do
      it 'should log and return nil if notification type is empty' do
        expect(notification_center.add_notification_listener(
                 nil,
                 @callback_reference
        )).to eq(nil)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::ERROR, 'Notification type can not be empty.')
      end

      it 'should log and return nil if notification callback is empty' do
        expect(notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
                 nil
        )).to eq(nil)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::ERROR, 'Callback can not be empty.')
      end

      it 'should log and return nil if invalid notification type given' do
        expect(notification_center.add_notification_listener(
                 'Test notification type',
                 @callback_reference
        )).to eq(nil)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::ERROR, 'Invalid notification type.')
      end

      it 'should log and return nil if invalid callable given' do
        expect(notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
                 'Invalid callback!'
        )).to eq(nil)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::ERROR, 'Invalid notification callback given.')
      end
    end

    describe 'test add notification with valid type and callback' do
      it 'should add, and return notification ID when a plain function is passed as an argument ' do
        expect(notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
                 @callback_reference
        )).to eq(1)
        # verifies that one notification is added
        expect(notification_center.notifications[Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]].length)
          .to eq(1)
      end
    end

    describe 'test add notification for multiple notification types' do
      it 'should add and return notification ID when a valid callback is added for each notification type ' do
        Optimizely::NotificationCenter::NOTIFICATION_TYPES.values.each_with_index do |value, index|
          notification_id = index + 1
          expect(notification_center.add_notification_listener(
                   value,
                   @callback_reference
          )).to eq(notification_id)
        end
        notification_center.notifications.each_key do |key|
          expect(notification_center.notifications[key].length)
            .to eq(1)
        end
      end

      it 'should add and return notification ID when multiple
            valid callbacks are added for a single notification type' do
        class CallBackSecond
          def call(_args)
            'Test multi listner.'
          end
        end

        @callback_second = CallBackSecond.new
        @callback_reference_second = @callback_second.method(:call)
        expect(
          notification_center.add_notification_listener(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
            @callback_reference
          )
        ).to eq(1)
        expect(
          notification_center.add_notification_listener(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
            @callback_reference_second
          )
        ).to eq(2)

        expect(
          notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
          ].length
        ).to eq(2)
      end
    end

    describe 'test add notification that already added callback is not re-added' do
      it 'should return -1 if callback already added' do
        notification_center.add_notification_listener(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
          @callback_reference
        )
        expect(notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
                 @callback_reference
        )).to eq(-1)
      end

      it 'should add same callback for a different notification type' do
        expect(notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
                 @callback_reference
        )).to eq(1)

        expect(notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK],
                 @callback_reference
        )).to eq(2)
      end
    end

    describe 'test remove notification' do
      let(:raise_error_handler) { Optimizely::RaiseErrorHandler.new }
      let(:notification_center) { Optimizely::NotificationCenter.new(spy_logger, raise_error_handler) }
      before(:example) do
        @inner_notification_center = notification_center
        class CallBackSecond
          def call(_args)
            'Test remove notification.'
          end
        end

        @callback_second = CallBackSecond.new
        @callback_reference_second = @callback_second.method(:call)
        # add a callback for multiple notification types

        expect(@inner_notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
                 @callback_reference
        )).to eq(1)

        expect(@inner_notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK],
                 @callback_reference
        )).to eq(2)

        # add another callback for NOTIFICATION_TYPES::ACTIVATE
        expect(@inner_notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
                 @callback_reference_second
        )).to eq(3)
        # Verify that notifications length for NOTIFICATION_TYPES::ACTIVATE is 2
        expect(@inner_notification_center.notifications[
         Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]].length).to eq(2)
        # Verify that notifications length for NotificationType::TRACK is 1
        expect(@inner_notification_center.notifications[
         Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK]].length).to eq(1)
      end

      it 'should not remove callback for empty notification ID' do
        expect(@inner_notification_center.remove_notification_listener(nil)).to eq(nil)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::ERROR, 'Notification ID can not be empty.')

        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
          ].length
        ).to eq(2)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK]
          ].length
        ).to eq(1)
      end

      it 'should not remove callback for an invalid notification ID' do
        expect(@inner_notification_center.remove_notification_listener(4))
          .to eq(false)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
          ].length
        ).to eq(2)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK]
          ].length
        ).to eq(1)
      end

      it 'should remove callback for a valid notification ID' do
        expect(@inner_notification_center.remove_notification_listener(3))
          .to eq(true)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
          ].length
        ).to eq(1)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK]
          ].length
        ).to eq(1)
      end

      it 'should not remove callback once a callback has already been removed against a notification ID' do
        expect(@inner_notification_center.remove_notification_listener(3))
          .to eq(true)
        expect(@inner_notification_center.remove_notification_listener(3))
          .to eq(false)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
          ].length
        ).to eq(1)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK]
          ].length
        ).to eq(1)
      end

      it 'should not remove notifications for an invalid notification type' do
        invalid_type = 'Invalid notification'
        expect { @inner_notification_center.clear_notifications(invalid_type) }
          .to raise_error(Optimizely::InvalidNotificationType)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::ERROR, 'Invalid notification type.')
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
          ].length
        ).to eq(2)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK]
          ].length
        ).to eq(1)
      end

      it 'should remove all notifications for a valid notification type' do
        notification_type = Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
        @inner_notification_center.clear_notifications(notification_type)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::INFO, "All callbacks for notification type #{notification_type} have been removed.")
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
          ].length
        ).to eq(0)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK]
          ].length
        ).to eq(1)
      end

      it 'should not throw an error when clear_notifications is called again for the same notification type' do
        notification_type = Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
        @inner_notification_center.clear_notifications(notification_type)
        expect { @inner_notification_center.clear_notifications(notification_type) }
          .to_not raise_error(Optimizely::InvalidNotificationType)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
          ].length
        ).to eq(0)
        expect(
          @inner_notification_center.notifications[
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK]
          ].length
        ).to eq(1)
      end
    end

    describe 'clear all notifications' do
      let(:raise_error_handler) { Optimizely::RaiseErrorHandler.new }
      let(:notification_center) { Optimizely::NotificationCenter.new(spy_logger, raise_error_handler) }
      before(:example) do
        @inner_notification_center = notification_center
        class CallBackSecond
          def call(_args)
            'Test remove notification.'
          end
        end

        @callback_second = CallBackSecond.new
        @callback_reference_second = @callback_second.method(:call)

        class CallBackThird
          def call(_args)
            'Test remove notification.'
          end
        end

        @callback_third = CallBackThird.new
        @callback_reference_third = @callback_third.method(:call)

        # verify that for each of the notification types, the notifications length is zero
        @inner_notification_center.notifications.each_key do |key|
          expect(@inner_notification_center.notifications[key]).to be_empty
        end
        #  add a callback for multiple notification types
        expect(@inner_notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
                 @callback_reference
        )).to eq(1)

        expect(@inner_notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
                 @callback_reference_second
        )).to eq(2)

        expect(@inner_notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
                 @callback_reference_third
        )).to eq(3)

        expect(@inner_notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK],
                 @callback_reference
        )).to eq(4)

        expect(@inner_notification_center.add_notification_listener(
                 Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK],
                 @callback_reference_second
        )).to eq(5)

        # verify that notifications length for each type reflects the just added callbacks

        expect(@inner_notification_center.notifications[
         Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]].length).to eq(3)

        expect(@inner_notification_center.notifications[
         Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK]].length).to eq(2)
      end

      it 'should remove all notifications for each notification type' do
        @inner_notification_center.clean_all_notifications
        @inner_notification_center.notifications.each_key do |key|
          expect(@inner_notification_center.notifications[key]).to be_empty
        end
      end

      it 'clean_all_notifications does not throw an error when called again' do
        @inner_notification_center.clean_all_notifications
        expect { @inner_notification_center.clean_all_notifications }
          .to_not raise_error
      end
    end

    describe '.send_notifications' do
      class Invitation
        def initialize(logger)
          @logger = logger
        end

        def deliver_one(_args)
          @logger.log Logger::INFO, 'delivered one.'
        end

        def deliver_two(_args)
          @logger.log Logger::INFO, 'delivered two.'
        end

        def deliver_three(_args)
          @logger.log Logger::INFO, 'delivered three.'
        end
      end
      let(:raise_error_handler) { Optimizely::RaiseErrorHandler.new }
      let(:invitation) { Invitation.new(spy_logger) }
      let(:notification_center) { Optimizely::NotificationCenter.new(spy_logger, raise_error_handler) }
      before(:example) do
        config = Optimizely::ProjectConfig.new(config_body_JSON, spy_logger, error_handler)
        @event_builder = Optimizely::EventBuilder.new(config)
        @args = [
          config.get_experiment_from_key('test_experiment'),
          'test_user',
          {},
          '111128',
          @event_builder.create_impression_event(
            config.get_experiment_from_key('test_experiment'),
            '111128', 'test_user', nil
          )
        ]
      end

      it 'should not raise error and send single notification for a single type' do
        notification_type = Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
        notification_center.add_notification_listener(notification_type, invitation.method(:deliver_one))
        notification_center.notifications[notification_type].each do |notification|
          notification_callback = notification[:callback]
          expect { notification_callback.call(@args) }.to_not raise_error
        end
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::INFO, 'delivered one.')
      end

      it 'should return nil when notification type not valid' do
        notification_type = Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
        notification_center.add_notification_listener(notification_type, invitation.method(:deliver_one))
        expect { notification_center.send_notifications('test_type', @args) }
          .to raise_error(Optimizely::InvalidNotificationType)
      end

      it 'should return nil and log when args are invalid' do
        notification_type = Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
        notification_center.add_notification_listener(notification_type, invitation.method(:deliver_one))
        expect(notification_center.send_notifications(notification_type)).to eq(nil)
        expect(spy_logger).to_not have_received(:log)
          .with(Logger::INFO, 'delivered one.')
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::ERROR,
                                                   'Problem calling notify callback. Error: wrong number of arguments (given 0, expected 1)'
                                                 )
      end

      it 'should send multiple notifications for a single type' do
        notification_type = Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
        notification_center.add_notification_listener(notification_type, invitation.method(:deliver_one))
        notification_center.add_notification_listener(notification_type, invitation.method(:deliver_two))
        notification_center.send_notifications(notification_type, @args)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::INFO, 'delivered one.')
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::INFO, 'delivered two.')
      end

      it 'should send notifications and verify that all callbacks are called' do
        notification_type_decision = Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE]
        notification_type_track = Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK]

        notification_center.add_notification_listener(notification_type_decision, invitation.method(:deliver_one))
        notification_center.add_notification_listener(notification_type_decision, invitation.method(:deliver_two))
        notification_center.add_notification_listener(notification_type_track, invitation.method(:deliver_three))

        notification_center.send_notifications(notification_type_decision, @args)
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::INFO, 'delivered one.')
        expect(spy_logger).to have_received(:log).once
                                                 .with(Logger::INFO, 'delivered two.')

        # Verifies that all callbacks for NotificationType::ACTIVATE are called and no other callbacks are called
        expect(spy_logger).to_not have_received(:log)
          .with(Logger::INFO, 'delivered three.')
      end
    end

    describe '@error_handler' do
      let(:raise_error_handler) { Optimizely::RaiseErrorHandler.new }
      let(:notification_center) { Optimizely::NotificationCenter.new(spy_logger, raise_error_handler) }

      describe 'validate notification type' do
        it 'should raise an error when provided notification type is invalid' do
          expect { notification_center.add_notification_listener('invalid_key', @callback_reference) }
            .to raise_error(Optimizely::InvalidNotificationType)
        end
      end
    end
  end
end
