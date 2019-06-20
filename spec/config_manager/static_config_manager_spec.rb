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
require 'optimizely/config_manager/static_config_manager'
require 'optimizely/error_handler'
require 'optimizely/helpers/validator'
require 'optimizely/logger'
describe Optimizely::StaticConfigManager do
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_config_manager) { Optimizely::StaticConfigManager.new(config_body_JSON, spy_logger, error_handler) }

  describe '#set_config' do
    it 'should set config when datafile is valid' do
      allow(project_config_manager).to receive(:set_config).and_call_original
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::DEBUG, 'Received new datafile and updated config. ' \
        'Old revision number: . New revision number: 42.')
    end

    it 'should update config when set_config called twice with same content' do
      allow(project_config_manager).to receive(:set_config).and_call_original
      # Call set config again and confirm that log message logged once.
      project_config_manager.send(:set_config, config_body_JSON)
      expect(spy_logger).to have_received(:log)
        .once.with(Logger::DEBUG, 'Received new datafile and updated config. ' \
        'Old revision number: . New revision number: 42.').ordered # Order: 1
    end

    it 'should not validate the JSON schema of the datafile when skip_json_validation is true' do
      expect(Optimizely::Helpers::Validator).not_to receive(:datafile_valid?)

      Optimizely::StaticConfigManager.new(config_body_JSON, spy_logger, error_handler, true)
    end

    it 'should validate the JSON schema of the datafile when skip_json_validation is false' do
      expect(Optimizely::Helpers::Validator).to receive(:datafile_valid?)

      Optimizely::StaticConfigManager.new(config_body_JSON, spy_logger, error_handler, false)
    end
  end
end
