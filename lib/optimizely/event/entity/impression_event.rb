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
require_relative 'user_event'
module Optimizely
  class ImpressionEvent < UserEvent
    attr_reader :event_context, :user_id, :experiment, :variation, :visitor_attributes,
                :bot_filtering

    def initialize(
      event_context,
      user_id,
      experiment,
      variation,
      visitor_attributes,
      bot_filtering
    )
      @event_context = event_context
      @user_id = user_id
      @experiment = experiment
      @variation = variation
      @visitor_attributes = visitor_attributes
      @bot_filtering = bot_filtering
    end
  end
end
