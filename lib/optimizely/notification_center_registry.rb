# frozen_string_literal: true

#
#    Copyright 2023, Optimizely and contributors
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
require_relative 'notification_center'
require_relative 'exceptions'

module Optimizely
  class NotificationCenterRegistry
    private_class_method :new
    # Class managing internal notification centers.
    # @api no-doc
    @notification_centers = {}
    @mutex = Mutex.new

    # Returns an internal notification center for the given sdk_key, creating one
    # if none exists yet.
    #
    # Args:
    # sdk_key: A string sdk key to uniquely identify the notification center.
    # logger: Optional logger.

    # Returns:
    # nil or NotificationCenter
    def self.get_notification_center(sdk_key, logger)
      unless sdk_key
        logger&.log(Logger::ERROR, "#{MissingSdkKeyError.new.message} ODP may not work properly without it.")
        return nil
      end

      notification_center = nil

      @mutex.synchronize do
        if @notification_centers.key?(sdk_key)
          notification_center = @notification_centers[sdk_key]
        else
          notification_center = NotificationCenter.new(logger, nil)
          @notification_centers[sdk_key] = notification_center
        end
      end

      notification_center
    end

    # Remove a previously added notification center and clear all its listeners.

    # Args:
    # sdk_key: The sdk_key of the notification center to remove.
    def self.remove_notification_center(sdk_key)
      @mutex.synchronize do
        @notification_centers
          .delete(sdk_key)
          &.clear_all_notification_listeners
      end
      nil
    end
  end
end
