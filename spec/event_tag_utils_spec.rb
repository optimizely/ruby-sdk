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

  describe '.get_revenue_value' do
    it 'should return nil if argument is not a Hash' do
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(nil)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(0.5)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(65536)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(9223372036854775807)).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value('65536')).to be_nil
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(false)).to be_nil
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
        'revenue' => '65536',
      }
      expect(Optimizely::Helpers::EventTagUtils.get_revenue_value(event_tags)).to be_nil
    end
    it 'should return nil if event tags contains the revenue with a boolean value' do
      event_tags = {
        'revenue' => true,
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
end
