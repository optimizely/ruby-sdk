# frozen_string_literal: true

#
#    Copyright 2020, Optimizely and contributors
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
require 'optimizely/optimizely_user_context'

describe 'Optimizely', :decide do
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:config_body_invalid_JSON) { OptimizelySpec::INVALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_instance) { Optimizely::Project.new(config_body_JSON, nil, spy_logger, error_handler) }

  describe '#initialize' do
    it 'should set passed value as expected' do
      user_id = 'test_user'
      attributes = {' browser' => 'firefox'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, attributes)

      expect(user_context_obj.instance_variable_get(:@optimizely_client)). to eq(project_instance)
      expect(user_context_obj.instance_variable_get(:@user_id)). to eq(user_id)
      expect(user_context_obj.instance_variable_get(:@user_attributes)). to eq(attributes)
    end

    it 'should set user attributes to empty hash when passed nil' do
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, 'test_user', nil)
      expect(user_context_obj.instance_variable_get(:@user_attributes)). to eq({})
    end
  end

  describe '#set_attribute' do
    it 'should add attribute key and value is attributes hash' do
      user_id = 'test_user'
      attributes = {' browser' => 'firefox'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, attributes)
      user_context_obj.set_attribute('id', 49)

      expected_attributes = attributes
      expected_attributes['id'] = 49
      expect(user_context_obj.instance_variable_get(:@user_attributes)). to eq(expected_attributes)
    end

    it 'should override attribute value if key already exists in hash' do
      user_id = 'test_user'
      attributes = {' browser' => 'firefox', 'color' => ' red'}
      user_context_obj = Optimizely::OptimizelyUserContext.new(project_instance, user_id, attributes)
      user_context_obj.set_attribute('browser', 'chrome')

      expected_attributes = attributes
      expected_attributes['browser'] = 'chrome'

      expect(user_context_obj.instance_variable_get(:@user_attributes)). to eq(expected_attributes)
    end

    it 'should not alter original attributes object when attrubute is modifed' do
    end
  end
end
