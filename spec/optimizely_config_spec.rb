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

describe Optimizely::OptimizelyConfig do
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
    expect(features_map.length).to eq(10)
    project_config.feature_flags.each do |feature_flag|
      expect(features_map[feature_flag['key']]).to include(
        'id' => feature_flag['id'],
        'key' => feature_flag['key']
      )
      experiments_map = features_map[feature_flag['key']]['experimentsMap']
      feature_flag['experimentIds'].each do |experiment_id|
        experiment_key = project_config.get_experiment_key(experiment_id)
        expect(experiments_map[experiment_key]).to be_truthy
      end
      variables_map = features_map[feature_flag['key']]['variablesMap']
      feature_flag['variables'].each do |variable|
        expect(variables_map[variable['key']]).to include(
          'id' => variable['id'],
          'key' => variable['key'],
          'type' => variable['type'],
          'value' => variable['defaultValue']
        )
      end
    end
  end

  it 'should correctly merge all feature variables' do
    project_config.feature_flags.each do |feature_flag|
      feature_flag['experimentIds'].each do |experiment_id|
        experiment = project_config.experiment_id_map[experiment_id]
        variations = experiment['variations']
        variations_map = optimizely_config['experimentsMap'][experiment['key']]['variationsMap']
        variations.each do |variation|
          feature_flag['variables'].each do |variable|
            variable_to_assert = variations_map[variation['key']]['variablesMap'][variable['key']]
            expect(variable).to include(
              'id' => variable_to_assert['id'],
              'key' => variable_to_assert['key'],
              'type' => variable_to_assert['type']
            )
            expect(variable['defaultValue']).to eq(variable_to_assert['value']) unless variation['featureEnabled']
          end
        end
      end
    end
  end

  it 'should return correct config revision' do
    expect(project_config.revision).to eq(optimizely_config['revision'])
  end
end
