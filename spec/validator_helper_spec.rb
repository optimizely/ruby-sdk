# frozen_string_literal: true

#
#    Copyright 2018-2019, Optimizely and contributors
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

  describe '.boolean?' do
    it 'should return true when passed value is boolean type' do
      expect(Optimizely::Helpers::Validator.boolean?(true)).to eq(true)
      expect(Optimizely::Helpers::Validator.boolean?(false)).to eq(true)
    end

    it 'should return false when passed value is not boolean type' do
      expect(Optimizely::Helpers::Validator.boolean?(nil)).to eq(false)
      expect(Optimizely::Helpers::Validator.boolean?(0)).to eq(false)
      expect(Optimizely::Helpers::Validator.boolean?(1)).to eq(false)
      expect(Optimizely::Helpers::Validator.boolean?(1.0)).to eq(false)
      expect(Optimizely::Helpers::Validator.boolean?('test')).to eq(false)
      expect(Optimizely::Helpers::Validator.boolean?([])).to eq(false)
      expect(Optimizely::Helpers::Validator.boolean?({})).to eq(false)
    end
  end

  describe '.same_types?' do
    it 'should return true when passed values are of same types' do
      expect(Optimizely::Helpers::Validator.same_types?(true, false)).to eq(true)
      expect(Optimizely::Helpers::Validator.same_types?(0, 10)).to eq(true)
      expect(Optimizely::Helpers::Validator.same_types?(0.0, 10.5)).to eq(true)
      expect(Optimizely::Helpers::Validator.same_types?('', 'test')).to eq(true)
      expect(Optimizely::Helpers::Validator.same_types?([], [])).to eq(true)
      expect(Optimizely::Helpers::Validator.same_types?({}, {})).to eq(true)
      # Fixnum and Bignum
      expect(Optimizely::Helpers::Validator.same_types?(10, 10_000_000_000_000_000_000)).to eq(true)
    end

    it 'should return false when passed values are of different types' do
      expect(Optimizely::Helpers::Validator.same_types?(true, 1)).to eq(false)
      expect(Optimizely::Helpers::Validator.same_types?(0, false)).to eq(false)
      expect(Optimizely::Helpers::Validator.same_types?(0, 0.0)).to eq(false)
      expect(Optimizely::Helpers::Validator.same_types?(0, '0.0')).to eq(false)
      expect(Optimizely::Helpers::Validator.same_types?({}, [])).to eq(false)
    end
  end

  describe '.finite_number?' do
    it 'should return true when passed finite value' do
      expect(Optimizely::Helpers::Validator.finite_number?(0)).to eq(true)
      expect(Optimizely::Helpers::Validator.finite_number?(5)).to eq(true)
      expect(Optimizely::Helpers::Validator.finite_number?(5.5)).to eq(true)
      # Upper limit
      expect(Optimizely::Helpers::Validator.finite_number?((2**53) - 1)).to eq(true)
      # float(2.0**53) + 1 evaluates to float(2.0**53)
      expect(Optimizely::Helpers::Validator.finite_number?((2.0**53) + 1)).to eq(true)
      # Lower limit
      expect(Optimizely::Helpers::Validator.finite_number?((-2**53) + 1)).to eq(true)
      # float(-2.0**53) - 1 evaluates to float(-2.0**53)
      expect(Optimizely::Helpers::Validator.finite_number?((-2.0**53) - 1)).to eq(true)
      # exact number integer
      expect(Optimizely::Helpers::Validator.finite_number?(2**53)).to eq(true)
      expect(Optimizely::Helpers::Validator.finite_number?(-2**53)).to eq(true)
      # exact number float
      expect(Optimizely::Helpers::Validator.finite_number?(2.0**53)).to eq(true)
      expect(Optimizely::Helpers::Validator.finite_number?(-2.0**53)).to eq(true)
    end

    it 'should return false when passed invalid value' do
      expect(Optimizely::Helpers::Validator.finite_number?('test')).to eq(false)
      expect(Optimizely::Helpers::Validator.finite_number?(true)).to eq(false)
      expect(Optimizely::Helpers::Validator.finite_number?(false)).to eq(false)
      expect(Optimizely::Helpers::Validator.finite_number?(nil)).to eq(false)
      expect(Optimizely::Helpers::Validator.finite_number?([])).to eq(false)
      expect(Optimizely::Helpers::Validator.finite_number?({})).to eq(false)
    end

    it 'should return false when passed invalid number' do
      # Infinity
      expect(Optimizely::Helpers::Validator.finite_number?(1 / 0.0)).to eq(false)
      # -Infinity
      expect(Optimizely::Helpers::Validator.finite_number?(-1 / 0.0)).to eq(false)
      # NaN
      expect(Optimizely::Helpers::Validator.finite_number?(0.0 / 0)).to eq(false)
      # Greater than specified limit of 2 ^ 53
      expect(Optimizely::Helpers::Validator.finite_number?((2**53) + 1)).to eq(false)
      expect(Optimizely::Helpers::Validator.finite_number?((2.0**53) + 2)).to eq(false)
      # Less than specified limit of -2 ^ 53
      expect(Optimizely::Helpers::Validator.finite_number?((-2**53) - 1)).to eq(false)
      expect(Optimizely::Helpers::Validator.finite_number?((-2**53) - 2.0)).to eq(false)
    end
  end
end
