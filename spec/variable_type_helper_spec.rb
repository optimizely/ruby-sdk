# frozen_string_literal: true
#
#    Copyright 2017, Optimizely and contributors
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
require 'optimizely/helpers/variable_type'

describe 'VariableTypeHelper' do
  let(:spy_logger) { spy('logger') }

  describe '.cast_value_to_type' do
    it 'should cast variable value to boolean' do
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('true', 'boolean', spy_logger)).to eq(true)
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('false', 'boolean', spy_logger)).to eq(false)
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('somestring', 'boolean', spy_logger)).to eq(false)
    end

    it 'should cast variable value to double' do
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('13.37', 'double', spy_logger)).to eq(13.37)
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('1000', 'double', spy_logger)).to eq(1000)
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('3.0', 'double', spy_logger)).to eq(3.0)
    end

    it 'should cast variable value to integer' do
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('1000', 'integer', spy_logger)).to eq(1000)
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('123', 'integer', spy_logger)).to eq(123)
    end

    it 'should cast variable value to string' do
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('13.37', 'string', spy_logger)).to eq('13.37')
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('a string', 'string', spy_logger)).to eq('a string')
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('3', 'string', spy_logger)).to eq('3')
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('false', 'string', spy_logger)).to eq('false')
    end

    it 'should return nil if cannot cast value to double' do
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('not a double', 'double', spy_logger)).to eq(nil)
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('false', 'double', spy_logger)).to eq(nil)
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::ERROR, "Unable to cast variable value 'not a double' to "\
                                  "type 'double': invalid value for Float(): \"not a double\".")
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::ERROR, "Unable to cast variable value 'false' to "\
                                  "type 'double': invalid value for Float(): \"false\".")
    end

    it 'should return nil if cannot cast value to integer' do
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('not an integer', 'integer', spy_logger)).to eq(nil)
      expect(Optimizely::Helpers::VariableType.cast_value_to_type('13.37', 'integer', spy_logger)).to eq(nil)
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::ERROR, "Unable to cast variable value 'not an integer' to "\
                                  "type 'integer': invalid value for Integer(): \"not an integer\".")
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::ERROR, "Unable to cast variable value '13.37' to type "\
                                  "'integer': invalid value for Integer(): \"13.37\".")
    end
  end
end
