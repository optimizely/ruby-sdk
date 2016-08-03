require 'logger'

module Optimizely
  class BaseLogger
    # Class encapsulating logging functionality. Override with your own logger providing log method.

    def log(_level, _message)
    end
  end

  class NoOpLogger < BaseLogger
    # Class providing log method which logs nothing.

    def log(_level, _message)
    end
  end

  class SimpleLogger < BaseLogger
    # Simple wrapper around Logger.

    def initialize(min_level = Logger::INFO)
      @logger = Logger.new(STDOUT)
      @logger.level = min_level
    end

    def log(level, message)
      @logger.add(level, message)
    end
  end
end
