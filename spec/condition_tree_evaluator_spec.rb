# frozen_string_literal: true

#
#    Copyright 2019, Optimizely and contributors
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
require 'json'
require 'spec_helper'

describe Optimizely::ConditionTreeEvaluator do
  before(:example) do
    @browser_condition = {'name' => 'browser_type', 'type' => 'custom_attribute', 'value' => 'firefox'}
    @device_condition =  {'name' => 'device', 'type' => 'custom_attribute', 'value' => 'iphone'}
    @location_condition = {'name' => 'location', 'type' => 'custom_attribute', 'value' => 'san francisco'}
  end

  describe 'evaluate' do
    it 'should return true for a leaf condition when the leaf condition evaluator returns true' do
      leaf_callback = ->(_condition) { return true }
      expect(Optimizely::ConditionTreeEvaluator.evaluate(@browser_condition, leaf_callback)).to be true
    end

    it 'should return false for a leaf condition when the leaf condition evaluator returns false' do
      leaf_callback = ->(_condition) { return false }
      expect(Optimizely::ConditionTreeEvaluator.evaluate(@browser_condition, leaf_callback)).to be false
    end
  end

  describe 'and evaluation' do
    it 'should return true when ALL conditions evaluate to true' do
      leaf_callback = ->(_condition) { return true }
      expect(Optimizely::ConditionTreeEvaluator.evaluate(['and', @browser_condition, @device_condition], leaf_callback)).to be true
    end

    it 'should return false if one condition evaluates to false' do
      leaf_callback = double
      allow(leaf_callback).to receive(:call).and_return(true, false)
      expect(Optimizely::ConditionTreeEvaluator.evaluate(['and', @browser_condition, @device_condition], leaf_callback)).to be false
    end

    describe 'nil handling' do
      it 'should return nil when all operands evaluate to nil' do
        leaf_callback = ->(_condition) { return nil }
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['and', @browser_condition, @device_condition], leaf_callback)).to eq(nil)
      end

      it 'should return nil when operands evaluate to trues and nils' do
        leaf_callback = double
        allow(leaf_callback).to receive(:call).and_return(true, nil)
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['and', @browser_condition, @device_condition], leaf_callback)).to eq(nil)

        allow(leaf_callback).to receive(:call).and_return(nil, true)
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['and', @browser_condition, @device_condition], leaf_callback)).to eq(nil)
      end

      it 'should return false when operands evaluate to falses and nils' do
        leaf_callback = double
        allow(leaf_callback).to receive(:call).and_return(false, nil)
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['and', @browser_condition, @device_condition], leaf_callback)).to be false

        allow(leaf_callback).to receive(:call).and_return(nil, false)
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['and', @browser_condition, @device_condition], leaf_callback)).to be false
      end

      it 'should return false when operands evaluate to trues, falses, and nils' do
        leaf_callback = double
        allow(leaf_callback).to receive(:call).and_return(true, false, nil)
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['and', @browser_condition, @device_condition, @location_condition], leaf_callback)).to be false
      end
    end
  end

  describe 'or evaluation' do
    it 'should return false if all conditions evaluate to false' do
      leaf_callback = ->(_condition) { return false }
      expect(Optimizely::ConditionTreeEvaluator.evaluate(['or', @browser_condition, @device_condition], leaf_callback)).to be false
    end

    it 'should return true if any condition evaluates to true' do
      leaf_callback = double
      allow(leaf_callback).to receive(:call).and_return(false, true)
      expect(Optimizely::ConditionTreeEvaluator.evaluate(['or', @browser_condition, @device_condition], leaf_callback)).to be true
    end

    describe 'nil handling' do
      it 'should return nil when all operands evaluate to nil' do
        leaf_callback = ->(_condition) { return nil }
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['or', @browser_condition, @device_condition], leaf_callback)).to eq(nil)
      end

      it 'should return true when operands evaluate to trues and nils' do
        leaf_callback = double
        allow(leaf_callback).to receive(:call).and_return(true, nil)
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['or', @browser_condition, @device_condition], leaf_callback)).to be true

        allow(leaf_callback).to receive(:call).and_return(nil, true)
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['or', @browser_condition, @device_condition], leaf_callback)).to be true
      end

      it 'should return nil when operands evaluate to falses and nils' do
        leaf_callback = double
        allow(leaf_callback).to receive(:call).and_return(false, nil)
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['or', @browser_condition, @device_condition], leaf_callback)).to eq(nil)

        allow(leaf_callback).to receive(:call).and_return(nil, false)
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['or', @browser_condition, @device_condition], leaf_callback)).to eq(nil)
      end

      it 'should return true when operands evaluate to trues, falses, and nils' do
        leaf_callback = double
        allow(leaf_callback).to receive(:call).and_return(true, false, nil)
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['or', @browser_condition, @device_condition, @location_condition], leaf_callback)).to be true
      end
    end
  end

  describe 'not evaluation' do
    it 'should return true if the condition evaluates to false' do
      leaf_callback = ->(_condition) { return false }
      expect(Optimizely::ConditionTreeEvaluator.evaluate(['not', @browser_condition], leaf_callback)).to be true
    end

    it 'should return false if the condition evaluates to true' do
      leaf_callback = ->(_condition) { return true }
      expect(Optimizely::ConditionTreeEvaluator.evaluate(['not', @browser_condition], leaf_callback)).to be false
    end

    it 'should return the result of negating the first condition, and ignore any additional conditions' do
      leaf_callback = ->(id) { return id == '1' }
      expect(Optimizely::ConditionTreeEvaluator.evaluate(%w[not 1 2 1], leaf_callback)).to be false

      leaf_callback2 = ->(id) { return id == '2' }
      expect(Optimizely::ConditionTreeEvaluator.evaluate(%w[not 1 2 1], leaf_callback2)).to be true

      leaf_callback3 = ->(id) { return id == '1' ? nil : id == '3' }
      expect(Optimizely::ConditionTreeEvaluator.evaluate(%w[not 1 2 3], leaf_callback3)).to eq(nil)
    end

    describe 'nil handling' do
      it 'should return nil when operand evaluates to nil' do
        leaf_callback = ->(_condition) { return nil }
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['not', @browser_condition, @device_condition], leaf_callback)).to eq(nil)
      end

      it 'should return nil when there are no operands' do
        leaf_callback = ->(_condition) { return nil }
        expect(Optimizely::ConditionTreeEvaluator.evaluate(['not'], leaf_callback)).to eq(nil)
      end
    end
  end

  describe 'implicit operator' do
    it 'should behave like an "or" operator when the first item in the array is not a recognized operator' do
      leaf_callback = double
      allow(leaf_callback).to receive(:call).and_return(true, false)
      expect(Optimizely::ConditionTreeEvaluator.evaluate([@browser_condition, @device_condition], leaf_callback)).to be true

      leaf_callback = ->(_condition) { return false }
      allow(leaf_callback).to receive(:call).and_return(false, true)
      expect(Optimizely::ConditionTreeEvaluator.evaluate([@browser_condition, @device_condition], leaf_callback)).to be true
    end
  end
end
