module Optimizely
  class Error < StandardError; end

  class InvalidAudienceError < Error
    # Raised when an invalid audience is provided

    def initialize(msg = 'Provided audience is not in datafile.')
      super
    end
  end

  class InvalidAttributeError < Error
    # Raised when an invalid attribute is provided

    def initialize(msg = 'Provided attribute is not in datafile.')
      super
    end
  end

  class InvalidAttributeFormatError < Error
    # Raised when attributes are provided in an invalid format (e.g. not a Hash)

    def initialize(msg = 'Attributes provided are in an invalid format.')
      super
    end
  end

  class InvalidDatafileError < Error
    # Raised when an invalid datafile is provided

    def initialize(msg = 'Provided datafile is in an invalid format.')
      super
    end
  end

  class InvalidErrorHandlerError < Error
    # Raised when an invalid error handler is provided

    def initialize(msg = 'Provided error_handler is in an invalid format.')
      super
    end
  end

  class InvalidEventDispatcherError < Error
    # Raised when an invalid event dispatcher is provided

    def initialize(msg = 'Provided event_dispatcher is in an invalid format.')
      super
    end
  end

  class InvalidExperimentError < Error
    # Raised when an invalid experiment key is provided

    def initialize(msg = 'Provided experiment is not in datafile.')
      super
    end
  end

  class InvalidGoalError < Error
    # Raised when an invalid event key is provided

    def initialize(msg = 'Provided event is not in datafile.')
      super
    end
  end

  class InvalidLoggerError < Error
    # Raised when an invalid logger is provided

    def initialize(msg = 'Provided logger is in an invalid format.')
      super
    end
  end

  class InvalidVariationError < Error
    # Raised when an invalid variation key or ID is provided

    def initialize(msg = 'Provided variation is not in datafile.')
      super
    end
  end
end
