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
require_relative 'event_processor'
module Optimizely
  class ForwardingEventProcessor < EventProcessor
    # ForwardingEventProcessor is a basic transformation stage for converting
    # the event batch into a LogEvent to be dispatched.
    def initialize(event_dispatcher, logger = nil, notification_center = nil)
      @event_dispatcher = event_dispatcher
      @logger = logger || NoOpLogger.new
      @notification_center = notification_center
    end

    def process(user_event)
      log_event = Optimizely::EventFactory.create_log_event(user_event, @logger)

      begin
        Thread.new do
          begin
            @event_dispatcher.dispatch_event(log_event)

            @notification_center&.send_notifications(NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], log_event)
          rescue StandardError => e
            @logger.log(Logger::ERROR, "Error dispatching event: #{log_event} #{e.message}.")
          end
        end
      rescue StandardError => e
        @logger.log(Logger::ERROR, "Error dispatching event: #{log_event} #{e.message}.")
      end
    end
  end
end
