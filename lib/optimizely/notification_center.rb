#
#    Copyright 2017, Optimizely and contributors
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
module Optimizely
  class NotificationCenter
    attr_reader :notifications
    attr_reader :notification_id

    NOTIFICATION_TYPES = {
      ACTIVATE: 'ACTIVATE: experiment, user_id, attributes, variation, event',
      TRACK: 'TRACK: event_key, user_id, attributes, event_tags, event'
    }.freeze

    def initialize(logger, error_handler)
      @notification_id = 1
      @notifications = {}
      NOTIFICATION_TYPES.values.each { |value| @notifications[value] = [] }
      @logger = logger
      @error_handler = error_handler
    end

    def add_notification_listener(notification_type, notification_callback)
      # Adds notification callback to the notification center

      # Args:
      #  notification_type: one of the constants in NOTIFICATION_TYPES
      #  notification_callback: function to call when the event is fired

      # Returns:
      #  notification ID used to remove the notification

      return nil unless notification_type_valid?(notification_type)

      unless notification_callback
        @logger.log Logger::ERROR, 'Callback can not be empty.'
        return nil
      end

      unless notification_callback.is_a? Method
        @logger.log Logger::ERROR, 'Invalid notification callback given.'
        return nil
      end

      @notifications[notification_type].each do |notification|
        return -1 if notification[:callback] == notification_callback
      end
      @notifications[notification_type].push(notification_id: @notification_id, callback: notification_callback)
      notification_id = @notification_id
      @notification_id += 1
      notification_id
    end

    def remove_notification_listener(notification_id)
      # Removes previously added notification callback

      # Args:
      #  notification_id:
      # Returns:
      #  The function returns true if found and removed, false otherwise
      unless notification_id
        @logger.log Logger::ERROR, 'Notification ID can not be empty.'
        return nil
      end
      @notifications.each do |key, _array|
        @notifications[key].each do |notification|
          if notification_id == notification[:notification_id]
            @notifications[key].delete(notification_id: notification_id, callback: notification[:callback])
            return true
          end
        end
      end
      false
    end

    def clear_notifications(notification_type)
      # Removes notifications for a certain notification type
      #
      # Args:
      #  notification_type: one of the constants in NOTIFICATION_TYPES

      return nil unless notification_type_valid?(notification_type)

      @notifications[notification_type] = []
      @logger.log Logger::INFO, "All callbacks for notification type #{notification_type} have been removed."
    end

    def clean_all_notifications
      # Removes all notifications
      @notifications.keys.each { |key| @notifications[key] = [] }
    end

    def fire_notifications(notification_type, *args)
      # Fires off the notification for the specific event.  Uses var args to pass in a
      # arbitrary list of parameters according to which notification type was fired

      # Args:
      #  notification_type: one of the constants in NOTIFICATION_TYPES
      #  args: list of arguments to the callback
      return nil unless notification_type_valid?(notification_type)

      @notifications[notification_type].each do |notification|
        begin
          notification_callback = notification[:callback]
          notification_callback.call(*args)
          @logger.log Logger::INFO, "Notification #{notification_type} sent successfully."
        rescue => e
          @logger.log(Logger::ERROR, "Problem calling notify callback. Error: #{e}")
          return nil
        end
      end
    end

    private

    def notification_type_valid?(notification_type)
      # Validates notification type

      # Args:
      #  notification_type: one of the constants in NOTIFICATION_TYPES

      # Returns true if notification_type is valid,  false otherwise

      unless notification_type
        @logger.log Logger::ERROR, 'Notification type can not be empty.'
        return false
      end

      unless @notifications.include?(notification_type)
        @logger.log Logger::ERROR, 'Invalid notification type.'
        @error_handler.handle_error InvalidNotificationType
        return false
      end
      true
    end
  end
end
