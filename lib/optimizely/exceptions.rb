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

  class InvalidVariationError < Error
    # Raised when an invalid variation key or ID is provided

    def initialize(msg = 'Provided variation is not in datafile.')
      super
    end
  end

  class InvalidDatafileError < Error
    # Raised when a public method fails due to an invalid datafile

    def initialize(aborted_method)
      super("Provided datafile is in an invalid format. Aborting #{aborted_method}")
    end
  end

  class InvalidDatafileVersionError < Error
    # Raised when a datafile with an unsupported version is provided

    def initialize(msg = 'Provided datafile is an unsupported version.')
      super
    end
  end

  class InvalidInputError < Error
    # Abstract error raised when an invalid input is provided during Project instantiation

    def initialize(type)
      super("Provided #{type} is in an invalid format.")
    end
  end
end
