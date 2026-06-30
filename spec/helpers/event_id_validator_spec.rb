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
require 'spec_helper'
require 'optimizely/helpers/event_id_validator'

describe Optimizely::Helpers::EventIdValidator do
  describe '.numeric_string?' do
    it 'accepts a non-empty string of decimal digits' do
      expect(described_class.numeric_string?('12345')).to be true
    end

    it 'accepts a single digit' do
      expect(described_class.numeric_string?('0')).to be true
    end

    it 'accepts leading zeros' do
      expect(described_class.numeric_string?('007')).to be true
    end

    it 'rejects nil' do
      expect(described_class.numeric_string?(nil)).to be false
    end

    it 'rejects empty string' do
      expect(described_class.numeric_string?('')).to be false
    end

    it 'rejects whitespace-only string' do
      expect(described_class.numeric_string?('   ')).to be false
    end

    it 'rejects string with leading whitespace' do
      expect(described_class.numeric_string?(' 12345')).to be false
    end

    it 'rejects string with trailing whitespace' do
      expect(described_class.numeric_string?('12345 ')).to be false
    end

    it 'rejects integer (non-string)' do
      expect(described_class.numeric_string?(12_345)).to be false
    end

    it 'rejects symbol' do
      expect(described_class.numeric_string?(:'12345')).to be false
    end

    it 'rejects negative numeric strings' do
      expect(described_class.numeric_string?('-1')).to be false
    end

    it 'rejects decimal strings' do
      expect(described_class.numeric_string?('1.5')).to be false
    end

    it 'rejects exponent notation' do
      expect(described_class.numeric_string?('1e10')).to be false
    end

    it 'rejects hex strings' do
      expect(described_class.numeric_string?('0xff')).to be false
    end

    it 'rejects alphanumeric strings' do
      expect(described_class.numeric_string?('exp_42')).to be false
    end
  end

  describe '.non_empty_string?' do
    it 'accepts a non-empty numeric string' do
      expect(described_class.non_empty_string?('12345')).to be true
    end

    it 'accepts a non-empty opaque string with prefix' do
      expect(described_class.non_empty_string?('default-12345')).to be true
    end

    it 'accepts a non-empty opaque alphanumeric string' do
      expect(described_class.non_empty_string?('layer_abc')).to be true
    end

    it 'accepts a whitespace-only string (non-empty per spec)' do
      # FR-001: non-empty string is the only requirement; any character
      # content is acceptable for campaign_id/entity_id.
      expect(described_class.non_empty_string?('   ')).to be true
    end

    it 'rejects nil' do
      expect(described_class.non_empty_string?(nil)).to be false
    end

    it 'rejects empty string' do
      expect(described_class.non_empty_string?('')).to be false
    end

    it 'rejects integer (non-string)' do
      # Non-string types are out of scope per spec; non_empty_string? rejects
      # them defensively to keep the wire payload string-typed.
      expect(described_class.non_empty_string?(12_345)).to be false
    end

    it 'rejects symbol' do
      expect(described_class.non_empty_string?(:'12345')).to be false
    end
  end

  describe '.normalize_campaign_id' do
    it 'returns the campaign_id unchanged when it is a non-empty numeric string' do
      expect(described_class.normalize_campaign_id('111122', '999888')).to eq('111122')
    end

    it 'returns the campaign_id unchanged when it is a non-empty opaque string (relaxed contract)' do
      # FR-001: any non-empty string is valid for campaign_id; opaque IDs
      # like "default-12345" or "layer_abc" pass through unchanged.
      expect(described_class.normalize_campaign_id('default-12345', '999888')).to eq('default-12345')
      expect(described_class.normalize_campaign_id('layer_abc', '999888')).to eq('layer_abc')
      expect(described_class.normalize_campaign_id('campaign_a', '999888')).to eq('campaign_a')
    end

    it 'returns the campaign_id unchanged when it is a whitespace-only string (non-empty per spec)' do
      # Whitespace is non-empty, so it passes through. The upstream datafile
      # producer is responsible for content quality; SDK only enforces
      # non-emptiness.
      expect(described_class.normalize_campaign_id('   ', '999888')).to eq('   ')
    end

    it 'returns experiment_id when campaign_id is nil' do
      expect(described_class.normalize_campaign_id(nil, '999888')).to eq('999888')
    end

    it 'returns experiment_id when campaign_id is empty string' do
      expect(described_class.normalize_campaign_id('', '999888')).to eq('999888')
    end

    it 'returns experiment_id (opaque string) when campaign_id is empty (relaxed contract)' do
      # FR-002 fallback also accepts opaque experiment_id values.
      expect(described_class.normalize_campaign_id('', 'exp_42')).to eq('exp_42')
    end

    it 'returns experiment_id when campaign_id is an integer (non-string, out of scope)' do
      # Non-string types are out of scope per spec; non_empty_string? rejects
      # them defensively so the fallback path still produces a string output.
      expect(described_class.normalize_campaign_id(111_122, '999888')).to eq('999888')
    end

    it 'returns empty string when both campaign_id and experiment_id are nil or empty' do
      expect(described_class.normalize_campaign_id(nil, nil)).to eq('')
      expect(described_class.normalize_campaign_id('', '')).to eq('')
      expect(described_class.normalize_campaign_id(nil, '')).to eq('')
      expect(described_class.normalize_campaign_id('', nil)).to eq('')
    end

    it 'preserves leading zeros' do
      expect(described_class.normalize_campaign_id('007', '999')).to eq('007')
    end
  end

  describe '.normalize_variation_id' do
    it 'returns the variation_id unchanged when it is a valid numeric string' do
      expect(described_class.normalize_variation_id('555444')).to eq('555444')
    end

    it 'returns nil when variation_id is nil' do
      expect(described_class.normalize_variation_id(nil)).to be_nil
    end

    it 'returns nil when variation_id is empty string' do
      expect(described_class.normalize_variation_id('')).to be_nil
    end

    it 'returns nil when variation_id is whitespace' do
      # variation_id retains the stricter numeric-only contract — whitespace
      # is not numeric, so it normalizes to nil even though it is non-empty.
      expect(described_class.normalize_variation_id('   ')).to be_nil
    end

    it 'returns nil when variation_id is a non-numeric placeholder string' do
      # variation_id stays strict (FR-003/FR-004) — opaque placeholders like
      # "variation_a" normalize to nil unlike campaign_id.
      expect(described_class.normalize_variation_id('variation_a')).to be_nil
    end

    it 'returns nil when variation_id is an integer (non-string, out of scope)' do
      expect(described_class.normalize_variation_id(555_444)).to be_nil
    end

    it 'preserves leading zeros' do
      expect(described_class.normalize_variation_id('042')).to eq('042')
    end
  end
end
