# frozen_string_literal: true

#
#    Copyright 2019, 2022, Optimizely and contributors
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
require_relative 'user_event'
require 'optimizely/helpers/date_time_utils'
module Optimizely
  class ConversionEvent < UserEvent
    # Represents conversion event
    attr_reader :event, :user_id, :visitor_attributes, :tags, :bot_filtering

    def initialize(
      event_context:,
      event:,
      user_id:,
      visitor_attributes:,
      tags:,
      bot_filtering:
    )
      super()
      @event_context = event_context
      @uuid = SecureRandom.uuid
      @timestamp = Helpers::DateTimeUtils.create_timestamp
      @event = event
      @user_id = user_id
      @visitor_attributes = visitor_attributes
      @tags = tags
      @bot_filtering = bot_filtering
    end
  end
end
