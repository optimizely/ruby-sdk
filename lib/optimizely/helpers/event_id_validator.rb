# frozen_string_literal: true

#
#    Copyright 2026, Optimizely and contributors
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
  module Helpers
    # EventIdValidator normalizes ID fields on outgoing decision events so
    # that the wire payload is byte-equivalent across SDKs (FSSDK-12813).
    #
    # A valid numeric ID is a non-empty string whose characters are entirely
    # decimal digits [0-9]. Leading zeros are allowed. Whitespace, signs,
    # decimal points, and exponents are NOT allowed.
    #
    # This module is silent by design: per spec it must NOT log or warn on the
    # normalization path (FR-007), and must NOT fail or defer event dispatch
    # (FR-006).
    module EventIdValidator
      module_function

      # Matches a non-empty string of decimal digits only (no sign, no
      # whitespace, no decimal point, no exponent).
      NUMERIC_STRING_PATTERN = /\A[0-9]+\z/

      # Returns true when value is a non-empty string consisting entirely of
      # decimal digits. Returns false for nil, non-strings, empty strings, or
      # strings containing any non-digit character (including whitespace).
      def numeric_string?(value)
        value.is_a?(String) && NUMERIC_STRING_PATTERN.match?(value)
      end

      # Normalize a decision's campaign_id (and impression event's entity_id).
      #
      # When the provided campaign_id is a valid numeric string, return it
      # unchanged. Otherwise, substitute experiment_id when experiment_id is
      # itself a valid numeric string. When neither is valid, return an empty
      # string so the wire payload remains a string (matching the legacy
      # behavior for empty experiment slots).
      def normalize_campaign_id(campaign_id, experiment_id)
        return campaign_id if numeric_string?(campaign_id)
        return experiment_id if numeric_string?(experiment_id)

        ''
      end

      # Normalize a decision's variation_id.
      #
      # When the provided variation_id is a valid numeric string, return it
      # unchanged. Otherwise return nil so the wire payload encodes the field
      # as JSON null.
      def normalize_variation_id(variation_id)
        return variation_id if numeric_string?(variation_id)

        nil
      end
    end
  end
end
