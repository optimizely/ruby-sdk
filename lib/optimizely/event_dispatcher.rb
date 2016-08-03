require 'httparty'

module Optimizely
  class EventDispatcher
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
