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
        HTTParty.get(event.url, headers: event.headers, query: event.params, timeout: REQUEST_TIMEOUT)
      elsif event.http_verb == :post
        HTTParty.post(event.url,
                 body: event.params.to_json,
                 headers: event.headers,
                 timeout: REQUEST_TIMEOUT)
      end
    end
  end
end
