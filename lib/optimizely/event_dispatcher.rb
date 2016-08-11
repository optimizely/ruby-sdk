require 'httparty'

module Optimizely
  class BaseEventDispatcher
    # Class encapsulating event dispatching functionality.
    # Override with your own EventDispatcher providing dispatch_event method.

    def dispatch_event(_url, _params)
    end
  end

  class NoOpEventDispatcher < BaseEventDispatcher
    # Class providing dispatch_event method which does nothing.

    def dispatch_event(_url, _params)
    end
  end

  class EventDispatcher < BaseEventDispatcher
    REQUEST_TIMEOUT = 10

    def dispatch_event(url, params)
      # Dispatch the event being represented by the Event object.
      #
      # url - URL to send impression/conversion event to.
      # params - Params to be sent to the impression/conversion event.

      HTTParty.get(url, query: params, timeout: REQUEST_TIMEOUT)
      rescue Timeout::Error => e
        return e
    end
  end
end
