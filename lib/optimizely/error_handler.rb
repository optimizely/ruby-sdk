# frozen_string_literal: true
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
