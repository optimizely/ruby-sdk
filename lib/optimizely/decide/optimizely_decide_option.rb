# frozen_string_literal: true

#    Copyright 2020, Optimizely and contributors
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
  module Decide
    module OptimizelyDecideOption
      DISABLE_DECISION_EVENT = 'DISABLE_DECISION_EVENT'
      ENABLED_FLAGS_ONLY = 'ENABLED_FLAGS_ONLY'
      IGNORE_USER_PROFILE_SERVICE = 'IGNORE_USER_PROFILE_SERVICE'
      INCLUDE_REASONS = 'INCLUDE_REASONS'
      EXCLUDE_VARIABLES = 'EXCLUDE_VARIABLES'
      IGNORE_CMAB_CACHE = 'IGNORE_CMAB_CACHE'
      RESET_CMAB_CACHE = 'RESET_CMAB_CACHE'
      INVALIDATE_USER_CMAB_CACHE = 'INVALIDATE_USER_CMAB_CACHE'
    end
  end
end
