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
require 'optimizely/helpers/event_tag_utils'

describe 'EventTagUtils' do

  let(:logger) { Optimizely::NoOpLogger.new }

  describe '.get_revenue_value' do
    it 'should return nil if argument is not a Hash' do
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(nil)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(0.5)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(65536)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(9223372036854775807)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value('65536')).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(false)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(true)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value([])).to be_nil
    end
    it 'should return nil if event tags does not contain the revenue' do
      event_tags = {
        'non-revenue' => 5432,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(event_tags)).to be_nil
    end
    it 'should return nil if event tags contains the revenue with a string value' do
      event_tags = {
        'revenue' => 'string',
      }
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(event_tags)).to be_nil
    end
    it 'should return nil if event tags contains the revenue with a string value' do
      event_tags = {
        'revenue' => '65536',
      }
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(event_tags)).to be_nil
    end
    it 'should return nil if event tags contains the revenue with a boolean true value' do
      event_tags = {
        'revenue' => true,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(event_tags)).to be_nil
    end
    it 'should return nil if event tags contains the revenue with a boolean false value' do
      event_tags = {
        'revenue' => false,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(event_tags)).to be_nil
    end
    it 'should return nil if event tags contains the revenue with a list value' do
      event_tags = {
        'revenue' => [],
      }
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(event_tags)).to be_nil
    end
    it 'should return nil if event tags contains the revenue with a float value' do
      event_tags = {
        'revenue' => 0.5,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(event_tags)).to be_nil
    end
    it 'should return correct value if event tags contains the revenue with an integer value' do
      event_tags = {
        'revenue' => 65536,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(event_tags)).to eq(65536)
    end
    it 'should return correct value if event tags contains the revenue with a long value' do
      event_tags = {
        'revenue' => 9223372036854775807,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(event_tags)).to eq(9223372036854775807)
    end

  end

  describe '.get_numeric_value' do
    let(:spy_logger) { spy('logger') }

    it 'should return nil if argument is undefined' do
      expect(spy_logger).to receive(:log).with(Logger::DEBUG,
                                                       "Event tags is undefined.").exactly(1).times
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(nil,spy_logger)).to be_nil
    end

    it 'should return nil if argument is not a Hash' do
      expect(spy_logger).to receive(:log).with(Logger::DEBUG,
                                                       "Event tags is not a dictionary.").exactly(7).times
     
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(0.5,spy_logger)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(65536,spy_logger)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(9223372036854775807,spy_logger)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value('65536',spy_logger)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(false,spy_logger)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(true,spy_logger)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value([],spy_logger)).to be_nil
    end

    it 'should return nil if event tags does not contain the numeric tag value' do
      expect(spy_logger).to receive(:log).with(Logger::DEBUG,
                                                       "The numeric metric key is not defined in the event tags.").exactly(1).times
      event_tags = {
        'non-value' => 5432,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
    end

    it 'should return nil if event tags contains the numeric tag value with NULL value' do
      expect(spy_logger).to receive(:log).with(Logger::DEBUG,
                                                       "The numeric metric key is null.").exactly(1).times
      event_tags = {
        'value' => nil,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
    end

    it 'should return nil if event tags contains the numeric metric tag  with a non-numeric string value' do
      expect(spy_logger).to receive(:log).with(Logger::DEBUG,
                                                       "Provided numeric value is not a numeric string.").exactly(2).times
      event_tags = {
        'value' => 'abcd',
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil

      event_tags = {
        'value' => '1,1234',
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
    end

    it 'should return nil if event tags contains the numeric metric tag with a boolean value' do
      expect(spy_logger).to receive(:log).with(Logger::DEBUG,
                                                       "Provided numeric value is a boolean, which is an invalid format.").exactly(2).times
      event_tags = {
        'value' => true,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
      event_tags = {
        'value' => false,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
    end

    it 'should return nil if event tags contains the numeric metric tag with invalid values' do
      expect(spy_logger).to receive(:log).with(Logger::DEBUG,
                                                       "Provided numeric value is in an invalid format.").exactly(6).times
      event_tags = {
        'value' => [],
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
       event_tags = {
        'value' => {},
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
      event_tags = {
        'value' => Float::NAN,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
      event_tags = {
        'value' => Float::INFINITY,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
      event_tags = {
        'value' => -Float::INFINITY,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
      event_tags = {
        'value' => Float::MAX*10,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to be_nil
    end

    it 'should return correct value if event tags contains the numeric metric tag with correct values' do
      expect(spy_logger).to receive(:log).with(Logger::INFO,
                                                       "The numeric metric value 0.5 will be sent to results.").exactly(1).times
      event_tags = {
        'value' => 0.5,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to eq(0.5)
 
      expect(spy_logger).to receive(:log).with(Logger::INFO,
                                                       "The numeric metric value 65536.0 will be sent to results.").exactly(1).times
      event_tags = {
        'value' => '65536',
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to eq(65536)

      expect(spy_logger).to receive(:log).with(Logger::INFO,
                                                       "The numeric metric value 65536.0 will be sent to results.").exactly(1).times
      event_tags = {
        'value' => 65536,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to eq(65536)

      expect(spy_logger).to receive(:log).with(Logger::INFO,
                                                       "The numeric metric value 0.0 will be sent to results.").exactly(1).times
      event_tags = {
        'value' => 0.0,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to eq(0.0)

      expect(spy_logger).to receive(:log).with(Logger::INFO,
                                                       "The numeric metric value #{Float::MAX} will be sent to results.").exactly(1).times
      event_tags = {
        'value' => Float::MAX,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to eq(Float::MAX)

      expect(spy_logger).to receive(:log).with(Logger::INFO,
                                                       "The numeric metric value #{Float::MIN} will be sent to results.").exactly(1).times
      event_tags = {
        'value' => Float::MIN,
      }
      expect(Optimizely::Helpers::EventTagUtils.get_numeric_value(event_tags,spy_logger)).to eq(Float::MIN)
    end
  
  end

end
