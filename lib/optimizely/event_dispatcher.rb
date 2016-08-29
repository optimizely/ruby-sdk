require 'httparty'

module Optimizely
  class NoOpEventDispatcher
    # Class providing dispatch_event method which does nothing.

    def dispatch_event(_url, _params, _http_verb)
    end
  end

  class EventDispatcher
    REQUEST_TIMEOUT = 10

    def dispatch_event(url, params, http_verb = :get)
      # Dispatch the event being represented by the Event object.
      #
      # http_verb - HTTP verb with which to send the event.
      # url - URL to send impression/conversion event to.
      # params - Params to be sent to the impression/conversion event.

      if http_verb == :get
        begin
          HTTParty.get(url, query: params, timeout: REQUEST_TIMEOUT)
        rescue Timeout::Error => e
          return e
        end
      end
    end
  end
end
