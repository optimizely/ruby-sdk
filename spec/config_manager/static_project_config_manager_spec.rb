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
require 'optimizely/error_handler'
require 'optimizely/logger'
describe Optimizely::StaticProjectConfigManager do
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:datafile_project_config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }

  describe '#config' do
    it 'should return project config instance' do
      static_config_manager = Optimizely::StaticProjectConfigManager.new(config_body_JSON, spy_logger, error_handler, false)

      # All instance variables values of static_config_manager
      static_config_manager_arr = static_config_manager.config.instance_variables.map do |attr|
        static_config_manager.config.instance_variable_get attr
      end

      # All instance variables values of datafile_project_config
      datafile_project_config_arr = datafile_project_config.instance_variables.map do |attr|
        datafile_project_config.instance_variable_get attr
      end

      expect(static_config_manager_arr).to eql(datafile_project_config_arr)
    end

    it 'should return nil when called with an invalid datafile' do
      static_config_manager = Optimizely::StaticProjectConfigManager.new('invalid', spy_logger, error_handler, false)
      expect(static_config_manager.config).to be_nil
    end
  end
end
