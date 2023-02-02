# frozen_string_literal: true

#    Copyright 2019-2022, Optimizely and contributors
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
  require 'json'
  class OptimizelyConfig
    include Optimizely::ConditionTreeEvaluator
    def initialize(project_config)
      @project_config = project_config
      @rollouts = @project_config.rollouts
      @audiences = []
      audience_id_lookup_dict = {}

      @project_config.typed_audiences.each do |typed_audience|
        @audiences.push(
          'id' => typed_audience['id'],
          'name' => typed_audience['name'],
          'conditions' => typed_audience['conditions'].to_json
        )
        audience_id_lookup_dict[typed_audience['id']] = typed_audience['id']
      end

      @project_config.audiences.each do |audience|
        next unless !audience_id_lookup_dict.key?(audience['id']) && (audience['id'] != '$opt_dummy_audience')

        @audiences.push(
          'id' => audience['id'],
          'name' => audience['name'],
          'conditions' => audience['conditions']
        )
      end
    end

    def config
      experiments_map_object = experiments_map
      features_map = get_features_map(experiments_id_map)
      {
        'sdkKey' => @project_config.sdk_key,
        'datafile' => @project_config.datafile,
        # This experimentsMap is for experiments of legacy projects only.
        # For flag projects, experiment keys are not guaranteed to be unique
        # across multiple flags, so this map may not include all experiments
        # when keys conflict. Use experimentRules and deliveryRules instead.
        'experimentsMap' => experiments_map_object,
        'featuresMap' => features_map,
        'revision' => @project_config.revision,
        'attributes' => get_attributes_list(@project_config.attributes),
        'audiences' => @audiences,
        'events' => get_events_list(@project_config.events),
        'environmentKey' => @project_config.environment_key
      }
    end

    private

    def experiments_id_map
      feature_variables_map = feature_variable_map
      audiences_id_map = audiences_map
      @project_config.experiments.reduce({}) do |experiments_map, experiment|
        feature_id = @project_config.experiment_feature_map.fetch(experiment['id'], []).first
        experiments_map.update(
          experiment['id'] => {
            'id' => experiment['id'],
            'key' => experiment['key'],
            'variationsMap' => get_variation_map(feature_id, experiment, feature_variables_map),
            'audiences' => replace_ids_with_names(experiment.fetch('audienceConditions', []), audiences_id_map) || ''
          }
        )
      end
    end

    def audiences_map
      @audiences.reduce({}) do |audiences_map, optly_audience|
        audiences_map.update(optly_audience['id'] => optly_audience['name'])
      end
    end

    def experiments_map
      experiments_id_map.values.reduce({}) do |experiments_key_map, experiment|
        experiments_key_map.update(experiment['key'] => experiment)
      end
    end

    def feature_variable_map
      @project_config.feature_flags.reduce({}) do |result_map, feature|
        result_map.update(feature['id'] => feature['variables'])
      end
    end

    def get_variation_map(feature_id, experiment, feature_variables_map)
      experiment['variations'].reduce({}) do |variations_map, variation|
        variation_object = {
          'id' => variation['id'],
          'key' => variation['key'],
          'featureEnabled' => variation['featureEnabled'],
          'variablesMap' => get_merged_variables_map(variation, feature_id, feature_variables_map)
        }
        variations_map.update(variation['key'] => variation_object)
      end
    end

    # Merges feature key and type from feature variables to variation variables.
    def get_merged_variables_map(variation, feature_id, feature_variables_map)
      return {} unless feature_id

      feature_variables = feature_variables_map[feature_id]
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
      feature_variables.reduce({}) do |variables_map, feature_variable|
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
        delivery_rules = get_delivery_rules(@rollouts, feature['rolloutId'], feature['id'])
        features_map.update(
          feature['key'] => {
            'id' => feature['id'],
            'key' => feature['key'],
            # This experimentsMap is deprecated. Use experimentRules and deliveryRules instead.
            'experimentsMap' => feature['experimentIds'].reduce({}) do |experiments_map, experiment_id|
              experiment_key = @project_config.experiment_id_map[experiment_id]['key']
              experiments_map.update(experiment_key => experiments_id_map[experiment_id])
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
              experiments_map.push(all_experiments_map[experiment_id])
            end,
            'deliveryRules' => delivery_rules
          }
        )
      end
    end

    def get_attributes_list(attributes)
      attributes.map do |attribute|
        {
          'id' => attribute['id'],
          'key' => attribute['key']
        }
      end
    end

    def get_events_list(events)
      events.map do |event|
        {
          'id' => event['id'],
          'key' => event['key'],
          'experimentIds' => event['experimentIds']
        }
      end
    end

    def lookup_name_from_id(audience_id, audiences_map)
      audiences_map[audience_id] || audience_id
    end

    def stringify_conditions(conditions, audiences_map)
      operand = 'OR'
      conditions_str = ''
      length = conditions.length
      return '' if length.zero?
      return "\"#{lookup_name_from_id(conditions[0], audiences_map)}\"" if length == 1 && !OPERATORS.include?(conditions[0])

      # Edge cases for lengths 0, 1 or 2
      if length == 2 && OPERATORS.include?(conditions[0]) && !conditions[1].is_a?(Array) && !OPERATORS.include?(conditions[1])
        return "\"#{lookup_name_from_id(conditions[1], audiences_map)}\"" if conditions[0] != 'not'

        return "#{conditions[0].upcase} \"#{lookup_name_from_id(conditions[1], audiences_map)}\""

      end
      if length > 1
        (0..length - 1).each do |n|
          # Operand is handled here and made Upper Case
          if OPERATORS.include?(conditions[n])
            operand = conditions[n].upcase
          # Check if element is a list or not
          elsif conditions[n].is_a?(Array)
            # Check if at the end or not to determine where to add the operand
            # Recursive call to call stringify on embedded list
            conditions_str += if n + 1 < length
                                "(#{stringify_conditions(conditions[n], audiences_map)}) "
                              else
                                "#{operand} (#{stringify_conditions(conditions[n], audiences_map)})"
                              end
          # If the item is not a list, we process as an audience ID and retrieve the name
          else
            audience_name = lookup_name_from_id(conditions[n], audiences_map)
            unless audience_name.nil?
              # Below handles all cases for one ID or greater
              conditions_str += if n + 1 < length - 1
                                  "\"#{audience_name}\" #{operand} "
                                elsif n + 1 == length
                                  "#{operand} \"#{audience_name}\""
                                else
                                  "\"#{audience_name}\" "
                                end
            end
          end
        end
      end
      conditions_str || ''
    end

    def replace_ids_with_names(conditions, audiences_map)
      !conditions.empty? ? stringify_conditions(conditions, audiences_map) : ''
    end

    def get_delivery_rules(rollouts, rollout_id, feature_id)
      audiences_id_map = audiences_map
      feature_variables_map = feature_variable_map
      rollout = rollouts.select { |selected_rollout| selected_rollout['id'] == rollout_id }
      if rollout.any?
        rollout = rollout[0]
        experiments = rollout['experiments']
        return experiments.map do |experiment|
          {
            'id' => experiment['id'],
            'key' => experiment['key'],
            'variationsMap' => get_variation_map(feature_id, experiment, feature_variables_map),
            'audiences' => replace_ids_with_names(experiment.fetch('audienceConditions', []), audiences_id_map) || ''
          }
        end
      end
      []
    end
  end
end
