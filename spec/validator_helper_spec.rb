# frozen_string_literal: true

#
#    Copyright 2018, Optimizely and contributors
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
require 'optimizely'
require 'optimizely/logger'
require 'optimizely/helpers/validator'

describe 'ValidatorHelper' do
  let(:spy_logger) { spy('logger') }

  describe '.attributes_valid?' do
    it 'should return true when valid attributes are passed' do
      expect(Optimizely::Helpers::Validator.attributes_valid?({})).to eq(true)
      expect(
        Optimizely::Helpers::Validator.attributes_valid?(
          boolean: false,
          double: 5.5,
          integer: 5,
          string: 'value'
        )
      ).to eq(true)
    end

    it 'should return false when invalid attributes are passed' do
      expect(Optimizely::Helpers::Validator.attributes_valid?('key: value')).to eq(false)
      expect(Optimizely::Helpers::Validator.attributes_valid?(%w[key value])).to eq(false)
      expect(Optimizely::Helpers::Validator.attributes_valid?(42)).to eq(false)
      expect(Optimizely::Helpers::Validator.attributes_valid?([])).to eq(false)
      expect(Optimizely::Helpers::Validator.attributes_valid?(false)).to eq(false)
    end
  end

  describe '.attribute_valid?' do
    it 'should return true when valid type attribute value is passed' do
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', 'value')).to eq(true)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', 5)).to eq(true)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', 5.5)).to eq(true)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', false)).to eq(true)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', true)).to eq(true)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', '')).to eq(true)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', 0)).to eq(true)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', 0.0)).to eq(true)
    end

    it 'should return false when invalid type attribute value is passed' do
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', {})).to eq(false)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', [])).to eq(false)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', nil)).to eq(false)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', key: 'value')).to eq(false)
      expect(Optimizely::Helpers::Validator.attribute_valid?('test_attribute', %w[key value])).to eq(false)
    end

    it 'should return true when valid attribute key is passed' do
      expect(Optimizely::Helpers::Validator.attribute_valid?('', 'value')).to eq(true)
      expect(Optimizely::Helpers::Validator.attribute_valid?(:test_attribute, 'value')).to eq(true)
    end

    it 'should return false when invalid attribute key is passed' do
      expect(Optimizely::Helpers::Validator.attribute_valid?(5, 'value')).to eq(false)
      expect(Optimizely::Helpers::Validator.attribute_valid?(true, 'value')).to eq(false)
      expect(Optimizely::Helpers::Validator.attribute_valid?(5.5, 'value')).to eq(false)
    end
  end
end
