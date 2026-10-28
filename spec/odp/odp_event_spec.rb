# frozen_string_literal: true

# Copyright 2026, Optimizely
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'spec_helper'
require 'optimizely/odp/odp_event'

describe Optimizely::OdpEvent do
  describe 'custom data with string keys matching the default symbol-keyed fields' do
    # String keys are what callers get back from parsed JSON (e.g. a testapp or any
    # non-Ruby-native caller), which previously collided with the default symbol keys
    # instead of overriding them, producing a hash with duplicate-looking keys that
    # fails JSON generation (FSSDK-13349).
    let(:custom_data) do
      {
        'data_source_type' => 'sdk',
        'data_source' => 'test_sdk',
        'data_source_version' => '0.0.1'
      }
    end

    let(:event) { described_class.new(type: 'fullstack', action: 'test_action', identifiers: {'fs_user_id' => 'user1'}, data: custom_data) }

    it 'overrides the default fields instead of duplicating them' do
      parsed = JSON.parse(event.to_json)
      expect(parsed['data']['data_source_type']).to eq('sdk')
      expect(parsed['data']['data_source']).to eq('test_sdk')
      expect(parsed['data']['data_source_version']).to eq('0.0.1')
    end

    it 'produces a hash with no duplicate symbol/string keys' do
      data = event.instance_variable_get(:@data)
      string_and_symbol_keys = data.keys.group_by(&:to_s)
      expect(string_and_symbol_keys.values.map(&:size).uniq).to eq([1])
    end

    it 'serializes without raising' do
      expect { event.to_json }.not_to raise_error
    end
  end

  describe 'custom data with keys not present in the defaults' do
    let(:event) { described_class.new(type: 'fullstack', action: 'test_action', identifiers: {'fs_user_id' => 'user1'}, data: {'custom_key' => 'custom_value'}) }

    it 'keeps the defaults and adds the custom field' do
      parsed = JSON.parse(event.to_json)
      expect(parsed['data']['data_source_type']).to eq('sdk')
      expect(parsed['data']['data_source']).to eq('ruby-sdk')
      expect(parsed['data']['custom_key']).to eq('custom_value')
    end
  end
end
