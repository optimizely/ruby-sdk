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

  describe '.normalize_campaign_id' do
    it 'returns the campaign_id unchanged when it is a valid numeric string' do
      expect(described_class.normalize_campaign_id('111122', '999888')).to eq('111122')
    end

    it 'returns experiment_id when campaign_id is nil' do
      expect(described_class.normalize_campaign_id(nil, '999888')).to eq('999888')
    end

    it 'returns experiment_id when campaign_id is empty string' do
      expect(described_class.normalize_campaign_id('', '999888')).to eq('999888')
    end

    it 'returns experiment_id when campaign_id is whitespace' do
      expect(described_class.normalize_campaign_id('   ', '999888')).to eq('999888')
    end

    it 'returns experiment_id when campaign_id is a non-numeric placeholder string' do
      expect(described_class.normalize_campaign_id('campaign_a', '999888')).to eq('999888')
    end

    it 'returns experiment_id when campaign_id is an integer (non-string)' do
      expect(described_class.normalize_campaign_id(111_122, '999888')).to eq('999888')
    end

    it 'returns empty string when both campaign_id and experiment_id are invalid' do
      expect(described_class.normalize_campaign_id(nil, nil)).to eq('')
      expect(described_class.normalize_campaign_id('', '')).to eq('')
      expect(described_class.normalize_campaign_id('campaign_a', 'exp_b')).to eq('')
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
      expect(described_class.normalize_variation_id('   ')).to be_nil
    end

    it 'returns nil when variation_id is a non-numeric placeholder string' do
      expect(described_class.normalize_variation_id('variation_a')).to be_nil
    end

    it 'returns nil when variation_id is an integer (non-string)' do
      expect(described_class.normalize_variation_id(555_444)).to be_nil
    end

    it 'preserves leading zeros' do
      expect(described_class.normalize_variation_id('042')).to eq('042')
    end
  end
end
