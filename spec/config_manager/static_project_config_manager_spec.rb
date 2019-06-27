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
require 'spec_helper'
require 'optimizely/config_manager/static_project_config_manager'
describe Optimizely::StaticProjectConfigManager do
  describe '#config' do
    it 'should return project config instance' do
      expect_project_config = Optimizely::DatafileProjectConfig.new(OptimizelySpec::VALID_CONFIG_BODY_JSON, nil, nil)
      project_config_manager = Optimizely::StaticProjectConfigManager.new(expect_project_config)
      expect(project_config_manager.config).to eq(expect_project_config)
    end
  end
end
