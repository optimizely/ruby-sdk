#
#    Copyright 2016, Optimizely and contributors
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
require 'httparty'

module Optimizely
  class NoOpEventDispatcher
    # Class providing dispatch_event method which does nothing.

    def dispatch_event(event)
    end
  end

  class EventDispatcher
    REQUEST_TIMEOUT = 10

    def dispatch_event(event)
      # Dispatch the event being represented by the Event object.
      #
      # event - Event object

      if event.http_verb == :get
        begin
          HTTParty.get(event.url, headers: event.headers, query: event.params, timeout: REQUEST_TIMEOUT)
        rescue Timeout::Error => e
          return e
        end
      elsif event.http_verb == :post
        begin
          HTTParty.post(event.url,
                   body: event.params.to_json,
                   headers: event.headers,
                   timeout: REQUEST_TIMEOUT)
        rescue Timeout::Error => e
          return e
        end
      end
    end
  end
end
