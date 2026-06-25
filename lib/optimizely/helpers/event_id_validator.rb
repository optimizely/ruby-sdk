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
    # Two contracts apply:
    #   * campaign_id and entity_id (impression events): valid iff non-empty
    #     string. Any character content is acceptable — IDs may be opaque,
    #     e.g. "default-12345", "layer_abc". The fallback to experiment_id
    #     fires ONLY when the value is empty string, nil, or missing.
    #   * variation_id: valid iff non-empty string of decimal digits [0-9].
    #     Leading zeros are allowed. Whitespace, signs, decimal points, and
    #     exponents are NOT allowed. Falls back to nil otherwise.
    #
    # Non-string types (raw number, boolean, object) are out of scope per
    # spec — behavior on such inputs is undefined and not asserted.
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
      # Used for variation_id (which retains the stricter numeric-only
      # contract).
      def numeric_string?(value)
        value.is_a?(String) && NUMERIC_STRING_PATTERN.match?(value)
      end

      # Returns true when value is a non-empty string of any character
      # content. Returns false for nil, non-strings, or empty strings.
      # Used for campaign_id and entity_id (which accept opaque IDs).
      def non_empty_string?(value)
        value.is_a?(String) && !value.empty?
      end

      # Normalize a decision's campaign_id (and impression event's entity_id).
      #
      # When the provided campaign_id is a non-empty string (numeric or
      # opaque), return it unchanged. Otherwise, substitute experiment_id
      # when experiment_id is itself a non-empty string. When neither is a
      # non-empty string, return whatever experiment_id was (typically '' or
      # nil) so the wire payload remains consistent with upstream contract.
      def normalize_campaign_id(campaign_id, experiment_id)
        return campaign_id if non_empty_string?(campaign_id)

        # Per FR-002, fall back to experiment_id. Per the spec edge case,
        # when experiment_id is itself empty/null we still emit the event
        # (FR-006) carrying whatever experiment_id value was present —
        # represented here as an empty string to preserve string typing on
        # the wire payload.
        return experiment_id if non_empty_string?(experiment_id)

        ''
      end

      # Normalize a decision's variation_id.
      #
      # When the provided variation_id is a valid numeric string, return it
      # unchanged. Otherwise return nil so the wire payload encodes the field
      # as JSON null. variation_id retains the stricter numeric-string-only
      # contract — opaque/non-numeric placeholders are normalized to nil.
      def normalize_variation_id(variation_id)
        return variation_id if numeric_string?(variation_id)

        nil
      end
    end
  end
end
