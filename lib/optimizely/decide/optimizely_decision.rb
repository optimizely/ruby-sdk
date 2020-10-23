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
    class OptimizelyDecision
      def initialize(
        variation_key: nil,
        enabled: nil,
        variables: nil,
        rule_key: nil,
        flag_key: nil,
        user_context: nil,
        reasons: nil
      )
        @variation_key = variation_key
        @enabled = enabled || false,
                   @variables = variables || {}
        @rule_key = rule_key
        @flag_key = flag_key
        @user_context = user_context
        @reasons = reasons || []
      end
    end
  end
end
