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

describe Optimizely::OptimizelyConfig, :focus => true do
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:config_typed_audience_JSON) { JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES) }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:project_instance) { Optimizely::Project.new(config_body_JSON, nil, spy_logger, error_handler) }
  let(:optimizely_config) { project_instance.get_optimizely_config }

  it 'should return all experiments' do
    experiments_map = optimizely_config['experimentsMap']
    expect(experiments_map.length).to eq(11)
    project_config.experiments.each do |experiment|
      expect(experiments_map[experiment['key']]).to include(
        'id' => experiment['id'],
        'key' => experiment['key']
      )
      variations_map = experiments_map[experiment['key']]['variationsMap']
      experiment['variations'].each do |variation|
        expect(variations_map[variation['key']]).to include(
          'id' => variation['id'],
          'key' => variation['key']
        )
      end
    end
  end

  it 'should return all feature flags' do
    features_map = optimizely_config['featuresMap']
    expect(features_map.length).to eq(8)
  end

  it 'should correctly merge all feature variables' do
  end

  it 'should return correct config revision' do
  end
end
