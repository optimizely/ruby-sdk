#
#    Copyright 2016, Optimizely
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
