# frozen_string_literal: true

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

module Optimizely
  class OptimizelyConfig
    def initialize(project_config)
      @project_config = project_config
    end

    def get_optimizely_config
      experiments_map = get_experiments_map
      features_map = get_features_map(experiments_map)
      return {
        'experimentsMap' => experiments_map,
        'featuresMap' => features_map,
        'revision' => @project_config.revision,
      }
    end

    private

    def get_experiments_map
      feature_variables_map = @project_config.feature_flags.reduce({}) { |result_map, feature|
        result_map.update(feature['id'] => feature['variables'])
      }
      return @project_config.experiments.reduce({}) { |experiments_map, experiment|
        exp = {
          'id' => experiment['id'],
          'key' => experiment['key'],
          'variationsMap' => experiment['variations'].reduce({}) { |variations_map, variation|
            variation_object = {
              'id' => variation['id'],
              'key' => variation['key'],              
              'variablesMap' => variation['variables'].reduce({}) { |variables_map, variable|
                variables_map.update(variable['id'] => {
                  'id' => variable['id'],
                  'value' => variable['value'],
                })
              },
            }
            if @project_config.feature_experiment?(experiment['id'])
              variation_object['featureEnabled'] = variation['featureEnabled']
            end
            variations_map.update(variation['key'] => variation_object)
          }
        }
        feature_ids = @project_config.experiment_feature_map[experiment['id']]
        if feature_ids
          merge_feature_variables(exp, feature_variables_map[feature_ids[0]])
        end
        experiments_map.update(experiment['key'] => exp)
      }
    end

    def merge_feature_variables(experiment, feature_variables)
      experiment['variationsMap'].each_value { |variation|
        feature_variables.each { |feature_variable|
          variation_variable = variation['variablesMap'][feature_variable['id']]
          variable_value = variation['featureEnabled'] && variation_variable ? variation_variable['value'] : feature_variable['defaultValue'] 
          variation['variablesMap'][feature_variable['key']] = {
            'id' => feature_variable['id'],
            'key' => feature_variable['key'],
            'type' => feature_variable['type'],
            'value' => variable_value,
          }
          # deleting the temporary entry
          if variation_variable
            variation['variablesMap'].delete(feature_variable['id'])
          end
        }
      }
    end

    def get_features_map(experiments_map)
      return @project_config.feature_flags.reduce({}) do |features_map, feature|
        features_map.update(feature['key'] => {
          'id' => feature['id'],
          'key' => feature['key'],
          'experimentsMap' => feature['experimentIds'].reduce({}) { |experiments, experiment_id|
            experiment_key = @project_config.experiment_id_map[experiment_id]['key']
            experiments.update(experiment_key => experiments_map[experiment_key])
          },
          'variablesMap' => feature['variables'].reduce({}) { |variables, variable|
            variables.update(variable['key'] => {
              'id' => variable['id'],
              'key' => variable['key'],
              'type' => variable['type'],
              'value' => variable['defaultValue'],
            })
          }
        })
      end
    end
  end
end
