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
require 'optimizely/config_manager/polling_config_manager'
require 'optimizely/exceptions'
require 'optimizely/error_handler'
require 'optimizely/helpers/constants'
require 'optimizely/helpers/validator'
require 'optimizely/logger'
describe Optimizely::PollingConfigManager do
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  # let(:project_config_manager) { Optimizely::StaticConfigManager.new(config_body_JSON, spy_logger, error_handler) }

  describe '#get_datafile_url' do
    it 'should raise exception when sdk key and url are nil' do
      url_template = Optimizely::Helpers::Constants::CONFIG_MANAGER['DATAFILE_URL_TEMPLATE']
      expect { Optimizely::PollingConfigManager.new(nil, config_body_JSON, 1, nil, url_template, spy_logger, error_handler, true) }
        .to raise_error(Optimizely::InvalidInputsError, 'Must provide at least one of sdk_key or url.')
    end

    it 'should raise exception when sdk key and url are nil' do
      # No url_template provided
      expect { Optimizely::PollingConfigManager.new('optly_datafile_key').send(:get_datafile_url, 'optly_datafile_key', nil, nil) }
        .to raise_error(Optimizely::InvalidInputsError, 'Invalid url_template  provided.')

      # Incorrect url_template provided
      expect { Optimizely::PollingConfigManager.new('optly_datafile_key').send(:get_datafile_url, 'optly_datafile_key', nil, true) }
        .to raise_error(Optimizely::InvalidInputsError, 'Invalid url_template true provided.')
    end

    it 'should return valid url when sdk key and template are provided' do
      test_sdk_key = 'optly_key'
      test_url_template = 'www.optimizelydatafiles.com/%s.json'
      expected_url = test_url_template % test_sdk_key
      expect(Optimizely::PollingConfigManager.new(test_sdk_key).send(
               :get_datafile_url, test_sdk_key, nil, test_url_template
             )).to eq(expected_url)
    end
  end
end
