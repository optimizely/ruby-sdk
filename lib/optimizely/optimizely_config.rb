# frozen_string_literal: true

#    Copyright 2019-2021, Optimizely and contributors
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
    include Optimizely::ConditionTreeEvaluator
    def initialize(project_config)
      @project_config = project_config
      @rollouts = @project_config.rollouts
      @audiences = []
      type_audiences = @project_config.typed_audiences
      optly_typed_audiences = []
      id_lookup_dict = {}
      type_audiences.each do |type_audience|
        optly_audience = {}
        optly_audience['id'] = type_audience['id']
        optly_audience['name'] = type_audience['name']
        optly_audience['conditions'] = type_audience['conditions']

        optly_typed_audiences.push(optly_audience)
        id_lookup_dict[type_audience['id']] = type_audience['id']

        @project_config.audiences.each do |old_audience|
          next unless id_lookup_dict.key?(old_audience['id']) && (old_audience['id'] != '$opt_dummy_audience')

          optly_audience = {}
          optly_audience['id'] = old_audience['id']
          optly_audience['name'] = old_audience['name']
          optly_audience['conditions'] = old_audience['conditions']

          optly_typed_audiences.push(optly_audience)
        end
      end
      @audiences = optly_typed_audiences
    end

    def config
      experiments_map_object = experiments_map
      features_map = get_features_map(experiments_map_object)
      config = {
        'datafile' => @project_config.datafile,
        'experimentsMap' => experiments_map_object,
        'featuresMap' => features_map,
        'revision' => @project_config.revision,
        'attributes' => get_attributes_list(@project_config.attributes),
        'audiences' => @audiences,
        'events' => get_events_list(@project_config.events)
      }
      config['sdkKey'] = @project_config.sdk_key if @project_config.sdk_key
      config['environmentKey'] = @project_config.environment_key if @project_config.environment_key
      config
    end

    private

    def experiments_map
      feature_variables_map = feature_variable_map
      audiences_map = {}
      @audiences.each do |optly_audience|
        audiences_map[optly_audience['id']] = optly_audience['name']
      end
      @project_config.experiments.reduce({}) do |experiments_map, experiment|
        experiments_map.update(
          experiment['key'] => {
            'id' => experiment['id'],
            'key' => experiment['key'],
            'variationsMap' => get_variation_map(experiment, feature_variables_map),
            'audiences' => replace_ids_with_names(experiment.fetch('audienceConditions', []), audiences_map) || ''
          }
        )
      end
    end

    def feature_variable_map
      @project_config.feature_flags.reduce({}) do |result_map, feature|
        result_map.update(feature['id'] => feature['variables'])
      end
    end

    def get_variation_map(experiment, feature_variables_map)
      experiment['variations'].reduce({}) do |variations_map, variation|
        variation_object = {
          'id' => variation['id'],
          'key' => variation['key'],
          'variablesMap' => get_merged_variables_map(variation, experiment['id'], feature_variables_map)
        }
        variation_object['featureEnabled'] = variation['featureEnabled'] if @project_config.feature_experiment?(experiment['id'])
        variations_map.update(variation['key'] => variation_object)
      end
    end

    # Merges feature key and type from feature variables to variation variables.
    def get_merged_variables_map(variation, experiment_id, feature_variables_map)
      feature_ids = @project_config.experiment_feature_map[experiment_id]
      return {} unless feature_ids

      experiment_feature_variables = feature_variables_map[feature_ids[0]]
      # temporary variation variables map to get values to merge.
      temp_variables_id_map = {}
      if variation['variables']
        temp_variables_id_map = variation['variables'].reduce({}) do |variables_map, variable|
          variables_map.update(
            variable['id'] => {
              'id' => variable['id'],
              'value' => variable['value']
            }
          )
        end
      end
      experiment_feature_variables.reduce({}) do |variables_map, feature_variable|
        variation_variable = temp_variables_id_map[feature_variable['id']]
        variable_value = variation['featureEnabled'] && variation_variable ? variation_variable['value'] : feature_variable['defaultValue']
        variables_map.update(
          feature_variable['key'] => {
            'id' => feature_variable['id'],
            'key' => feature_variable['key'],
            'type' => feature_variable['type'],
            'value' => variable_value
          }
        )
      end
    end

    def get_features_map(all_experiments_map)
      @project_config.feature_flags.reduce({}) do |features_map, feature|
        delivery_rules = get_delivery_rules(@rollouts, feature['rolloutId'])
        features_map.update(
          feature['key'] => {
            'id' => feature['id'],
            'key' => feature['key'],
            'experimentsMap' => feature['experimentIds'].reduce({}) do |experiments_map, experiment_id|
              experiment_key = @project_config.experiment_id_map[experiment_id]['key']
              experiments_map.update(experiment_key => all_experiments_map[experiment_key])
            end,
            'variablesMap' => feature['variables'].reduce({}) do |variables, variable|
              variables.update(
                variable['key'] => {
                  'id' => variable['id'],
                  'key' => variable['key'],
                  'type' => variable['type'],
                  'value' => variable['defaultValue']
                }
              )
            end,
            'experimentRules' => feature['experimentIds'].reduce([]) do |experiments_map, experiment_id|
              experiment_key = @project_config.experiment_id_map[experiment_id]['key']
              experiments_map.push(all_experiments_map[experiment_key])
            end,
            'deliveryRules' => delivery_rules
          }
        )
      end
    end

    def get_attributes_list(attributes)
      attributes_list = []
      attributes.each do |attribute|
        optly_attribute = {}
        optly_attribute['id'] = attribute['id']
        optly_attribute['key'] = attribute['key']

        attributes_list.push(optly_attribute)
      end
      attributes_list
    end

    def get_events_list(events)
      events_list = []
      events.each do |event|
        optly_event = {}
        optly_event['id'] = event['id']
        optly_event['key'] = event['key']
        optly_event['experimentIds'] = event['experimentIds']

        events_list.push(optly_event)
      end
      events_list
    end

    def lookup_name_from_id(audience_id, audiences_map)
      name = audiences_map[audience_id] || audience_id
      name
    end

    def stringify_conditions(conditions, audiences_map)
      operand = 'OR'
      conditions_str = ''
      length = conditions.length()
      return '' if length.zero?
      return '"' + lookup_name_from_id(conditions[0], audiences_map) + '"' if length == 1 && !OPERATORS.include?(conditions[0])

      if length == 2 && OPERATORS.include?(conditions[0]) && conditions[1].is_a?(Array) && !OPERATORS.include?(conditions[1])

        return '"' + lookup_name_from_id(conditions[1], audiences_map) + '"' if conditions[0] != 'not'

        return conditions[0].upcase + ' "' + lookup_name_from_id(conditions[1], audiences_map) + '"'

      end
      if length > 1
        (0..length - 1).each do |n|
          if OPERATORS.include?(conditions[n])
            operand = conditions[n].upcase
          elsif conditions[n].is_a?(Array)
            conditions_str += if n + 1 < length
                                '(' + stringify_conditions(conditions[n], audiences_map) + ') '
                              else
                                operand + ' (' + stringify_conditions(conditions[n], audiences_map) + ')'
                              end
          else
            audience_name = lookup_name_from_id(conditions[n], audiences_map)
            if audience_name.nil?
              conditions_str += if n + 1 < length - 1
                                  '"' + audience_name + '" ' + operand + ' '
                                elsif n + 1 == length
                                  operand + ' "' + audience_name + '"'
                                else
                                  '"' + audience_name + '" '
                                end
            end
          end
        end
      end
      conditions_str || ''
    end

    def replace_ids_with_names(conditions, audiences_map)
      if !conditions.nil?
        stringify_conditions(conditions, audiences_map)
      else
        ''
      end
    end

    def get_delivery_rules(rollouts, rollout_id)
      delivery_rules = []
      audiences_map = {}

      rollout = rollouts.select { |selected_rollout| selected_rollout['id'] == rollout_id }
      if rollout.any?
        rollout = rollout[0]
        @audiences.each do |optly_audience|
          audiences_map[optly_audience['id']] = optly_audience['name']
        end
        experiments = rollout['experiments']
        experiments.each do |experiment|
          optly_exp = {
            'id' => experiment['id'],
            'key' => experiment['key'],
            'variationsMap' => get_variation_map(experiment, feature_variable_map),
            'audiences' => replace_ids_with_names(experiment.fetch('audienceConditions', []), audiences_map) || ''
          }
          delivery_rules.push(optly_exp)
        end

      end
      delivery_rules
    end
  end
end
