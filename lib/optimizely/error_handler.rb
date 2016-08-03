module Optimizely
  class BaseErrorHandler
    # Class encapsulating exception handling functionality.
    # Override with your own exception handler providing a handle_error method.

    def handle_error(_error)
    end
  end

  class NoOpErrorHandler < BaseErrorHandler
    # Class providing handle_error method that suppresses errors.

    def handle_error(_error)
    end
  end

  class RaiseErrorHandler < BaseErrorHandler
    # Class providing a handle_error method that raises exceptions.

    def handle_error(error)
      raise error
    end
  end
end
