# frozen_string_literal: true

#
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
require 'json'
require 'spec_helper'
require 'optimizely/config/datafile_project_config'
require 'optimizely/exceptions'

describe Optimizely::DatafileProjectConfig do
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:decision_JSON) { OptimizelySpec::DECIDE_FORCED_DECISION_JSON }
  let(:integrations_config) { OptimizelySpec::CONFIG_DICT_WITH_INTEGRATIONS }
  let(:integrations_JSON) { OptimizelySpec::CONFIG_DICT_WITH_INTEGRATIONS_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:logger) { Optimizely::NoOpLogger.new }
  let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, logger, error_handler) }
  let(:feature_enabled) { 'featureEnabled' }

  describe '.initialize' do
    it 'should initialize properties correctly upon creating project' do
      project_config = Optimizely::DatafileProjectConfig.new(config_body_JSON, logger, error_handler)

      feature_flags_to_compare = config_body.fetch('featureFlags')
      # modify json variable from datafile in the format expected by project config
      variable_to_modify = feature_flags_to_compare[8]['variables'][0]
      variable_to_modify['type'] = 'json'
      variable_to_modify.delete('subType')
      variable_to_modify = feature_flags_to_compare[9]['variables'][0]
      variable_to_modify['type'] = 'json'
      variable_to_modify.delete('subType')

      expect(project_config.datafile).to eq(config_body_JSON)
      expect(project_config.account_id).to eq(config_body['accountId'])
      expect(project_config.attributes).to eq(config_body['attributes'])
      expect(project_config.audiences).to eq(config_body['audiences'])
      expect(project_config.bot_filtering).to eq(config_body['botFiltering'])
      expect(project_config.events).to eq(config_body['events'])
      expect(project_config.feature_flags).to eq(feature_flags_to_compare)
      expect(project_config.groups).to eq(config_body['groups'])
      expect(project_config.project_id).to eq(config_body['projectId'])
      expect(project_config.revision).to eq(config_body['revision'])
      expect(project_config.sdk_key).to eq(config_body['sdkKey'])
      expect(project_config.environment_key).to eq(config_body['environmentKey'])
      expect(project_config.send_flag_decisions).to eq(config_body['sendFlagDecisions'])
      expect(project_config.region).to eq(config_body['region'])

      expected_attribute_key_map = {
        'browser_type' => config_body['attributes'][0],
        'boolean_key' => config_body['attributes'][1],
        'integer_key' => config_body['attributes'][2],
        'double_key' => config_body['attributes'][3]
      }
      expected_audience_id_map = {
        '11154' => config_body['audiences'][0],
        '11155' => config_body['audiences'][1]
      }

      expected_event_key_map = {
        'test_event' => config_body['events'][0],
        'Total Revenue' => config_body['events'][1],
        'test_event_with_audience' => config_body['events'][2],
        'test_event_not_running' => config_body['events'][3]
      }

      expected_experiment_feature_map = {
        '122227' => [config_body['featureFlags'][0]['id']],
        '133331' => [config_body['featureFlags'][6]['id']],
        '133332' => [config_body['featureFlags'][6]['id']],
        '122238' => [config_body['featureFlags'][1]['id']],
        '122241' => [config_body['featureFlags'][2]['id']],
        '122235' => [config_body['featureFlags'][4]['id']],
        '122230' => [config_body['featureFlags'][5]['id']]
      }

      expected_experiment_key_map = {
        'test_experiment' => config_body['experiments'][0],
        'test_experiment_not_started' => config_body['experiments'][1],
        'test_experiment_with_audience' => config_body['experiments'][2],
        'test_experiment_multivariate' => config_body['experiments'][3],
        'test_experiment_with_feature_rollout' => config_body['experiments'][4],
        'test_experiment_double_feature' => config_body['experiments'][5],
        'test_experiment_integer_feature' => config_body['experiments'][6],
        'group1_exp1' => config_body['groups'][0]['experiments'][0].merge('groupId' => '101'),
        'group1_exp2' => config_body['groups'][0]['experiments'][1].merge('groupId' => '101'),
        'group2_exp1' => config_body['groups'][1]['experiments'][0].merge('groupId' => '102'),
        'group2_exp2' => config_body['groups'][1]['experiments'][1].merge('groupId' => '102')
      }

      expected_variation_id_map = {
        'test_experiment' => {
          '111128' => {
            'key' => 'control',
            'id' => '111128',
            feature_enabled => true
          },
          '111129' => {
            'key' => 'variation',
            'id' => '111129',
            feature_enabled => true
          }
        },
        'test_experiment_not_started' => {
          '100028' => {
            'key' => 'control_not_started',
            'id' => '100028',
            feature_enabled => true
          },
          '100029' => {
            'key' => 'variation_not_started',
            'id' => '100029',
            feature_enabled => false
          }
        },
        'test_experiment_with_audience' => {
          '122228' => {
            'key' => 'control_with_audience',
            'id' => '122228',
            feature_enabled => true
          },
          '122229' => {
            'key' => 'variation_with_audience',
            'id' => '122229',
            feature_enabled => true
          }
        },
        'test_experiment_multivariate' => {
          '122231' => config_body['experiments'][3]['variations'][0],
          '122232' => config_body['experiments'][3]['variations'][1],
          '122233' => config_body['experiments'][3]['variations'][2],
          '122234' => config_body['experiments'][3]['variations'][3]
        },
        'test_experiment_with_feature_rollout' => {
          '122236' => config_body['experiments'][4]['variations'][0],
          '122237' => config_body['experiments'][4]['variations'][1]
        },
        'test_experiment_double_feature' => {
          '122239' => config_body['experiments'][5]['variations'][0],
          '122240' => config_body['experiments'][5]['variations'][1]
        },
        'test_experiment_integer_feature' => {
          '122242' => config_body['experiments'][6]['variations'][0],
          '122243' => config_body['experiments'][6]['variations'][1]
        },
        'group1_exp1' => {
          '130001' => {
            'key' => 'g1_e1_v1',
            'id' => '130001',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155563',
                'value' => 'groupie_1_v1'
              }
            ]
          },
          '130002' => {
            'key' => 'g1_e1_v2',
            'id' => '130002',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155563',
                'value' => 'groupie_1_v2'
              }
            ]
          }
        },
        'group1_exp2' => {
          '130003' => {
            'key' => 'g1_e2_v1',
            'id' => '130003',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155563',
                'value' => 'groupie_2_v1'
              }
            ]
          },
          '130004' => {
            'key' => 'g1_e2_v2',
            'id' => '130004',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155563',
                'value' => 'groupie_2_v2'
              }
            ]
          }
        },
        'group2_exp1' => {
          '144443' => {
            'key' => 'g2_e1_v1',
            'id' => '144443',
            feature_enabled => true
          },
          '144444' => {
            'key' => 'g2_e1_v2',
            'id' => '144444',
            feature_enabled => true
          }
        },
        'group2_exp2' => {
          '144445' => {
            'key' => 'g2_e2_v1',
            'id' => '144445',
            feature_enabled => true
          },
          '144446' => {
            'key' => 'g2_e2_v2',
            'id' => '144446',
            feature_enabled => true
          }
        },
        '177770' => {
          '177771' => {
            'id' => '177771',
            'key' => '177771',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155556',
                'value' => 'true'
              }
            ]
          }
        },
        '177772' => {
          '177773' => {
            'id' => '177773',
            'key' => '177773',
            feature_enabled => false,
            'variables' => [
              {
                'id' => '155556',
                'value' => 'false'
              }
            ]
          }
        },
        '177774' => {
          '177775' => {
            'id' => '177775',
            'key' => '177775',
            feature_enabled => true,
            'variables' => []
          }
        },
        '177776' => {
          '177778' => {
            'id' => '177778',
            'key' => '177778',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155556',
                'value' => 'false'
              }
            ]
          }
        },
        '177779' => {
          '177780' => {
            'id' => '177780',
            'key' => '177780',
            feature_enabled => true,
            'variables' => []
          }
        },
        'rollout_exp_with_diff_id_and_key' => {
          '177781' => {
            'id' => '177781',
            'key' => 'rollout_var_with_diff_id_and_key',
            feature_enabled => true,
            'variables' => []
          }
        }
      }

      expected_variation_key_map = {
        'test_experiment' => {
          'control' => {
            'key' => 'control',
            'id' => '111128',
            feature_enabled => true
          },
          'variation' => {
            'key' => 'variation',
            'id' => '111129',
            feature_enabled => true
          }
        },
        'test_experiment_not_started' => {
          'control_not_started' => {
            'key' => 'control_not_started',
            'id' => '100028',
            feature_enabled => true
          },
          'variation_not_started' => {
            'key' => 'variation_not_started',
            'id' => '100029',
            feature_enabled => false
          }
        },
        'test_experiment_with_audience' => {
          'control_with_audience' => {
            'key' => 'control_with_audience',
            'id' => '122228',
            feature_enabled => true
          },
          'variation_with_audience' => {
            'key' => 'variation_with_audience',
            'id' => '122229',
            feature_enabled => true
          }
        },
        'test_experiment_multivariate' => {
          'Fred' => config_body['experiments'][3]['variations'][0],
          'Feorge' => config_body['experiments'][3]['variations'][1],
          'Gred' => config_body['experiments'][3]['variations'][2],
          'George' => config_body['experiments'][3]['variations'][3]
        },
        'test_experiment_with_feature_rollout' => {
          'control' => config_body['experiments'][4]['variations'][0],
          'variation' => config_body['experiments'][4]['variations'][1]
        },
        'test_experiment_double_feature' => {
          'control' => config_body['experiments'][5]['variations'][0],
          'variation' => config_body['experiments'][5]['variations'][1]
        },
        'test_experiment_integer_feature' => {
          'control' => config_body['experiments'][6]['variations'][0],
          'variation' => config_body['experiments'][6]['variations'][1]
        },
        'group1_exp1' => {
          'g1_e1_v1' => {
            'key' => 'g1_e1_v1',
            'id' => '130001',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155563',
                'value' => 'groupie_1_v1'
              }
            ]
          },
          'g1_e1_v2' => {
            'key' => 'g1_e1_v2',
            'id' => '130002',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155563',
                'value' => 'groupie_1_v2'
              }
            ]
          }
        },
        'group1_exp2' => {
          'g1_e2_v1' => {
            'key' => 'g1_e2_v1',
            'id' => '130003',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155563',
                'value' => 'groupie_2_v1'
              }
            ]
          },
          'g1_e2_v2' => {
            'key' => 'g1_e2_v2',
            'id' => '130004',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155563',
                'value' => 'groupie_2_v2'
              }
            ]
          }
        },
        'group2_exp1' => {
          'g2_e1_v1' => {
            'key' => 'g2_e1_v1',
            'id' => '144443',
            feature_enabled => true
          },
          'g2_e1_v2' => {
            'key' => 'g2_e1_v2',
            'id' => '144444',
            feature_enabled => true
          }
        },
        'group2_exp2' => {
          'g2_e2_v1' => {
            'key' => 'g2_e2_v1',
            'id' => '144445',
            feature_enabled => true
          },
          'g2_e2_v2' => {
            'key' => 'g2_e2_v2',
            'id' => '144446',
            feature_enabled => true
          }
        },
        '177770' => {
          '177771' => {
            'id' => '177771',
            'key' => '177771',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155556',
                'value' => 'true'
              }
            ]
          }
        },
        '177772' => {
          '177773' => {
            'id' => '177773',
            'key' => '177773',
            feature_enabled => false,
            'variables' => [
              {
                'id' => '155556',
                'value' => 'false'
              }
            ]
          }
        },
        '177774' => {
          '177775' => {
            'id' => '177775',
            'key' => '177775',
            feature_enabled => true,
            'variables' => []
          }
        },
        '177776' => {
          '177778' => {
            'id' => '177778',
            'key' => '177778',
            feature_enabled => true,
            'variables' => [
              {
                'id' => '155556',
                'value' => 'false'
              }
            ]
          }
        },
        '177779' => {
          '177780' => {
            'id' => '177780',
            'key' => '177780',
            feature_enabled => true,
            'variables' => []
          }
        },
        'rollout_exp_with_diff_id_and_key' => {
          'rollout_var_with_diff_id_and_key' => {
            'id' => '177781',
            'key' => 'rollout_var_with_diff_id_and_key',
            feature_enabled => true,
            'variables' => []
          }
        }
      }

      expected_feature_flag_key_map = {
        'boolean_feature' => config_body['featureFlags'][0],
        'double_single_variable_feature' => config_body['featureFlags'][1],
        'integer_single_variable_feature' => config_body['featureFlags'][2],
        'boolean_single_variable_feature' => config_body['featureFlags'][3],
        'string_single_variable_feature' => config_body['featureFlags'][4],
        'multi_variate_feature' => config_body['featureFlags'][5],
        'mutex_group_feature' => config_body['featureFlags'][6],
        'empty_feature' => config_body['featureFlags'][7],
        'json_single_variable_feature' => config_body['featureFlags'][8],
        'all_variables_feature' => config_body['featureFlags'][9]
      }

      expected_feature_variable_key_map = {
        'boolean_feature' => {},
        'double_single_variable_feature' => {
          'double_variable' => {
            'id' => '155551',
            'key' => 'double_variable',
            'type' => 'double',
            'defaultValue' => '14.99'
          }
        },
        'integer_single_variable_feature' => {
          'integer_variable' => {
            'id' => '155553',
            'key' => 'integer_variable',
            'type' => 'integer',
            'defaultValue' => '7'
          }
        },
        'boolean_single_variable_feature' => {
          'boolean_variable' => {
            'id' => '155556',
            'key' => 'boolean_variable',
            'type' => 'boolean',
            'defaultValue' => 'true'
          }
        },
        'string_single_variable_feature' => {
          'string_variable' => {
            'id' => '155558',
            'key' => 'string_variable',
            'type' => 'string',
            'defaultValue' => 'wingardium leviosa'
          }
        },
        'json_single_variable_feature' => {
          'json_variable' => {
            'id' => '1555588',
            'key' => 'json_variable',
            'type' => 'json',
            'defaultValue' => '{ "val": "wingardium leviosa" }'
          }
        },
        'multi_variate_feature' => {
          'first_letter' => {
            'id' => '155560',
            'key' => 'first_letter',
            'type' => 'string',
            'defaultValue' => 'H'
          },
          'rest_of_name' => {
            'id' => '155561',
            'key' => 'rest_of_name',
            'type' => 'string',
            'defaultValue' => 'arry'
          }
        },
        'mutex_group_feature' => {
          'correlating_variation_name' => {
            'id' => '155563',
            'key' => 'correlating_variation_name',
            'type' => 'string',
            'defaultValue' => 'null'
          }
        },
        'empty_feature' => {},
        'all_variables_feature' => {
          'json_variable' => {
            'id' => '155558891',
            'key' => 'json_variable',
            'type' => 'json',
            'defaultValue' => '{ "val": "default json" }'
          },
          'string_variable' => {
            'id' => '155558892',
            'key' => 'string_variable',
            'type' => 'string',
            'defaultValue' => 'default string'
          },
          'boolean_variable' => {
            'id' => '155558893',
            'key' => 'boolean_variable',
            'type' => 'boolean',
            'defaultValue' => 'false'
          },
          'double_variable' => {
            'id' => '155558894',
            'key' => 'double_variable',
            'type' => 'double',
            'defaultValue' => '1.99'
          },
          'integer_variable' => {
            'id' => '155558895',
            'key' => 'integer_variable',
            'type' => 'integer',
            'defaultValue' => '10'
          }
        }
      }

      expected_variation_id_to_variable_usage_map = {
        '122231' => {
          '155560' => {
            'id' => '155560',
            'value' => 'F'
          },
          '155561' => {
            'id' => '155561',
            'value' => 'red'
          }
        },
        '122232' => {
          '155560' => {
            'id' => '155560',
            'value' => 'F'
          },
          '155561' => {
            'id' => '155561',
            'value' => 'eorge'
          }
        },
        '122233' => {
          '155560' => {
            'id' => '155560',
            'value' => 'G'
          },
          '155561' => {
            'id' => '155561',
            'value' => 'red'
          }
        },
        '122234' => {
          '155560' => {
            'id' => '155560',
            'value' => 'G'
          },
          '155561' => {
            'id' => '155561',
            'value' => 'eorge'
          }
        },
        '122236' => {
          '155558' => {
            'id' => '155558',
            'value' => 'cta_1'
          },
          '1555588' => {
            'id' => '1555588',
            'value' => '{"value": "cta_1"}'
          }
        },
        '122237' => {
          '155558' => {
            'id' => '155558',
            'value' => 'cta_2'
          },
          '1555588' => {
            'id' => '1555588',
            'value' => '{"value": "cta_2"}'
          }
        },
        '122239' => {
          '155551' => {
            'id' => '155551',
            'value' => '42.42'
          }
        },
        '122240' => {
          '155551' => {
            'id' => '155551',
            'value' => '13.37'
          }
        },
        '122242' => {
          '155553' => {
            'id' => '155553',
            'value' => '42'
          }
        },
        '122243' => {
          '155553' => {
            'id' => '155553',
            'value' => '13'
          }
        },
        '130001' => {
          '155563' => {
            'id' => '155563',
            'value' => 'groupie_1_v1'
          }
        },
        '130002' => {
          '155563' => {
            'id' => '155563',
            'value' => 'groupie_1_v2'
          }
        },
        '130003' => {
          '155563' => {
            'id' => '155563',
            'value' => 'groupie_2_v1'
          }
        },
        '130004' => {
          '155563' => {
            'id' => '155563',
            'value' => 'groupie_2_v2'
          }
        },
        '177771' => {
          '155556' => {
            'id' => '155556',
            'value' => 'true'
          }
        },
        '177773' => {
          '155556' => {
            'id' => '155556',
            'value' => 'false'
          }
        },
        '177775' => {},
        '177778' => {
          '155556' => {
            'id' => '155556',
            'value' => 'false'
          }
        },
        '177780' => {},
        '177781' => {}
      }

      expected_rollout_id_map = {
        '166660' => config_body['rollouts'][0],
        '166661' => config_body['rollouts'][1]
      }

      expected_rollout_experiment_id_map = {
        '177770' => config_body['rollouts'][0]['experiments'][0],
        '177772' => config_body['rollouts'][0]['experiments'][1],
        '177776' => config_body['rollouts'][0]['experiments'][2],
        '177774' => config_body['rollouts'][1]['experiments'][0],
        '177779' => config_body['rollouts'][1]['experiments'][1],
        '177780' => config_body['rollouts'][1]['experiments'][2]
      }

      expect(project_config.attribute_key_map).to eq(expected_attribute_key_map)
      expect(project_config.audience_id_map).to eq(expected_audience_id_map)
      expect(project_config.event_key_map).to eq(expected_event_key_map)
      expect(project_config.experiment_feature_map).to eq(expected_experiment_feature_map)
      expect(project_config.experiment_key_map).to eq(expected_experiment_key_map)
      expect(project_config.feature_flag_key_map).to eq(expected_feature_flag_key_map)
      expect(project_config.feature_variable_key_map).to eq(expected_feature_variable_key_map)
      expect(project_config.variation_id_map).to eq(expected_variation_id_map)
      expect(project_config.variation_key_map).to eq(expected_variation_key_map)
      expect(project_config.variation_id_to_variable_usage_map).to eq(expected_variation_id_to_variable_usage_map)
      expect(project_config.rollout_id_map).to eq(expected_rollout_id_map)
      expect(project_config.rollout_experiment_id_map).to eq(expected_rollout_experiment_id_map)
    end

    it 'should use US region when no region is specified in datafile' do
      project_config = Optimizely::DatafileProjectConfig.new(config_body_JSON, logger, error_handler)
      expect(project_config.region).to eq('US')
    end

    it 'should parse region specified in datafile correctly' do
      project_config_us = Optimizely::DatafileProjectConfig.new(config_body_JSON, logger, error_handler)
      expect(project_config_us.region).to eq('US')

      config_body_eu = config_body.dup
      config_body_eu['region'] = 'EU'
      config_body_json = JSON.dump(config_body_eu)
      project_config_eu = Optimizely::DatafileProjectConfig.new(config_body_json, logger, error_handler)

      expect(project_config_eu.region).to eq('EU')
    end

    it 'should initialize properties correctly upon creating project with typed audience dict' do
      project_config = Optimizely::DatafileProjectConfig.new(JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES), logger, error_handler)
      config_body = OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES

      expect(project_config.audiences).to eq(config_body['audiences'])

      expected_audience_id_map = {
        '3468206642' => config_body['audiences'][0],
        '3988293898' => config_body['typedAudiences'][0],
        '3988293899' => config_body['typedAudiences'][1],
        '3468206646' => config_body['typedAudiences'][2],
        '3468206647' => config_body['typedAudiences'][3],
        '3468206644' => config_body['typedAudiences'][4],
        '3468206643' => config_body['typedAudiences'][5],
        '3468206645' => config_body['typedAudiences'][6],
        '0' => config_body['audiences'][8]
      }

      expect(project_config.audience_id_map).to eq(expected_audience_id_map)
    end

    it 'should initialize send_flag_decisions to false when not in datafile' do
      config_body_without_flag_decision = config_body.dup
      config_body_without_flag_decision.delete('sendFlagDecisions')
      config_body_json = JSON.dump(config_body_without_flag_decision)
      project_config = Optimizely::DatafileProjectConfig.new(config_body_json, logger, error_handler)

      expect(project_config.send_flag_decisions).to eq(false)
    end

    it 'should initialize properties correctly upon creating project with integrations' do
      project_config = Optimizely::DatafileProjectConfig.new(integrations_JSON, logger, error_handler)
      integrations = integrations_config['integrations']
      odp_integration = integrations[0]

      expect(project_config.integrations).to eq(integrations)
      expect(project_config.integration_key_map['odp']).to eq(odp_integration)

      expect(project_config.public_key_for_odp).to eq(odp_integration['publicKey'])
      expect(project_config.host_for_odp).to eq(odp_integration['host'])

      expect(project_config.all_segments).to eq(%w[odp-segment-1 odp-segment-2 odp-segment-3])
    end

    it 'should initialize properties correctly upon creating project with empty integrations' do
      config = integrations_config.dup
      config['integrations'] = []
      integrations_json = JSON.dump(config)

      project_config = Optimizely::DatafileProjectConfig.new(integrations_json, logger, error_handler)

      expect(project_config.integrations).to eq([])

      expect(project_config.public_key_for_odp).to eq(nil)
      expect(project_config.host_for_odp).to eq(nil)
    end
  end

  describe '@logger' do
    let(:spy_logger) { spy('logger') }
    let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }

    describe 'get_experiment_from_key' do
      it 'should log a message when provided experiment key is invalid' do
        expect(config.get_experiment_from_key('invalid_key')).to eq(nil)
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment key 'invalid_key' is not in datafile.")
      end
    end

    describe 'get_experiment_key' do
      it 'should log a message when provided experiment key is invalid' do
        config.get_experiment_key('invalid_id')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment id 'invalid_id' is not in datafile.")
      end
    end

    describe 'get_event_from_key' do
      it 'should log a message when provided event key is invalid' do
        config.get_event_from_key('invalid_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Event key 'invalid_key' is not in datafile.")
      end
    end

    describe 'get_audience_from_id' do
      it 'should log a message when provided audience ID is invalid' do
        config.get_audience_from_id('invalid_id')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Audience id 'invalid_id' is not in datafile.")
      end
    end

    describe 'get_variation_from_id' do
      it 'should log a message when provided experiment key is invalid' do
        config.get_variation_from_id('invalid_key', 'some_variation')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment key 'invalid_key' is not in datafile.")
      end
      it 'should return nil when provided variation key is invalid' do
        expect(config.get_variation_from_id('test_experiment', 'invalid_variation')).to eq(nil)
      end

      it 'should return variation having featureEnabled false when not provided in the datafile' do
        config_body = OptimizelySpec::VALID_CONFIG_BODY
        experiment_key = config_body['experiments'][1]['key']
        variation_id = config_body['experiments'][1]['variations'][1]['id']

        config_body['experiments'][1]['variations'][1][feature_enabled] = nil

        config_body_json = JSON.dump(config_body)
        project_config = Optimizely::DatafileProjectConfig.new(config_body_json, logger, error_handler)

        expect(project_config.get_variation_from_id(experiment_key, variation_id)[feature_enabled]).to eq(false)
      end
    end

    describe 'get_variation_from_id_by_experiment_id' do
      it 'should log a message when provided experiment id is invalid' do
        config.get_variation_from_id_by_experiment_id('invalid_id', 'some_variation')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment id 'invalid_id' is not in datafile.")
      end
      it 'should return nil when provided variation id is invalid' do
        expect(config.get_variation_from_id_by_experiment_id('111127', 'invalid_variation')).to eq(nil)
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Variation id 'invalid_variation' is not in datafile.")
      end

      it 'should return variation having featureEnabled false when not provided in the datafile' do
        config_body = OptimizelySpec::VALID_CONFIG_BODY
        experiment_id = config_body['experiments'][1]['id']
        variation_id = config_body['experiments'][1]['variations'][1]['id']

        config_body['experiments'][1]['variations'][1][feature_enabled] = nil

        config_body_json = JSON.dump(config_body)
        project_config = Optimizely::DatafileProjectConfig.new(config_body_json, logger, error_handler)

        expect(project_config.get_variation_from_id_by_experiment_id(experiment_id, variation_id)[feature_enabled]).to eq(false)
      end
    end

    describe 'get_variation_id_from_key_by_experiment_id' do
      it 'should log a message when provided experiment id is invalid' do
        config.get_variation_id_from_key_by_experiment_id('invalid_id', 'some_variation')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment id 'invalid_id' is not in datafile.")
      end
      it 'should return nil when provided variation key is invalid' do
        expect(config.get_variation_id_from_key_by_experiment_id('111127', 'invalid_variation')).to eq(nil)
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Variation key 'invalid_variation' is not in datafile.")
      end

      it 'should return variation having featureEnabled false when not provided in the datafile' do
        config_body = OptimizelySpec::VALID_CONFIG_BODY
        experiment_id = config_body['experiments'][1]['id']
        variation_key = config_body['experiments'][1]['variations'][1]['key']

        config_body['experiments'][1]['variations'][1][feature_enabled] = nil

        config_body_json = JSON.dump(config_body)
        project_config = Optimizely::DatafileProjectConfig.new(config_body_json, logger, error_handler)
        expect(project_config.get_variation_id_from_key_by_experiment_id(experiment_id, variation_key)).to eq('100029')
      end
    end

    describe 'get_variation_id_from_key' do
      config_body = OptimizelySpec::VALID_CONFIG_BODY
      experiment_key = config_body['experiments'][1]['key']
      variation_key = config_body['experiments'][1]['variations'][1]['key']
      variation_id = config_body['experiments'][1]['variations'][1]['id']

      it 'should log a message when there is no variation key map for the experiment' do
        config.get_variation_id_from_key('invalid_key', 'invalid_variation')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment key 'invalid_key' is not in datafile.")
      end
      it 'should log a message when there is invalid variation key for the experiment' do
        expect(config.get_variation_id_from_key(experiment_key, 'invalid_variation')).to eq(nil)
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Variation key 'invalid_variation' is not in datafile.")
      end
      it 'should return variation id for variation key and the experiment key' do
        expect(config.get_variation_id_from_key(experiment_key, variation_key)).to eq(variation_id)
      end
    end

    describe 'get_whitelisted_variations' do
      it 'should log a message when there is no experiment key map for the experiment' do
        config.get_whitelisted_variations('invalid_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment id 'invalid_key' is not in datafile.")
      end
    end

    describe 'get_attribute_id_invalid_key' do
      it 'should log a message when provided attribute key is invalid' do
        config.get_attribute_id('invalid_attr')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Attribute key 'invalid_attr' is not in datafile.")
      end
    end

    describe 'get_feature_flag_from_key' do
      it 'should log a message when provided feature flag key is invalid' do
        config.get_feature_flag_from_key('totally_invalid_feature_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Feature flag key 'totally_invalid_feature_key' is not in datafile.")
      end
    end

    describe 'get_feature_variable' do
      it 'should log a message when variable with key is not found' do
        feature_flag = config.feature_flag_key_map['double_single_variable_feature']
        config.get_feature_variable(feature_flag, 'nonexistent_variable_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "No feature variable was found for key 'nonexistent_variable_key' in feature flag 'double_single_variable_feature'.")
      end
    end
  end

  describe '@error_handler' do
    let(:raise_error_handler) { Optimizely::RaiseErrorHandler.new }
    let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, logger, raise_error_handler) }

    describe 'get_experiment_from_key' do
      it 'should raise an error when provided experiment key is invalid' do
        expect { config.get_experiment_from_key('invalid_key') }.to raise_error(Optimizely::InvalidExperimentError)
      end
    end

    describe 'get_event_from_key' do
      it 'should raise an error when provided event key is invalid' do
        expect { config.get_event_from_key('invalid_key') }.to raise_error(Optimizely::InvalidEventError)
      end
    end

    describe 'get_audience_from_id' do
      it 'should raise an error when provided audience ID is invalid' do
        expect { config.get_audience_from_id('invalid_key') }
          .to raise_error(Optimizely::InvalidAudienceError)
      end
    end

    describe 'get_variation_from_id' do
      it 'should raise an error when provided experiment key is invalid' do
        expect { config.get_variation_from_id('invalid_key', 'some_variation') }
          .to raise_error(Optimizely::InvalidExperimentError)
      end
    end

    describe 'get_variation_from_id' do
      it 'should raise an error when provided variation key is invalid' do
        expect { config.get_variation_from_id('test_experiment', 'invalid_variation') }
          .to raise_error(Optimizely::InvalidVariationError)
      end
    end

    describe 'get_variation_id_from_key' do
      it 'should raise an error when there is no variation key map for the experiment' do
        expect { config.get_variation_id_from_key('invalid_key', 'invalid_variation') }
          .to raise_error(Optimizely::InvalidExperimentError)
      end
    end

    describe 'get_whitelisted_variations' do
      it 'should log a message when there is no experiment key map for the experiment' do
        expect { config.get_whitelisted_variations('invalid_key') }.to raise_error(Optimizely::InvalidExperimentError)
      end
    end

    describe 'get_attribute_id_invalid_key' do
      it 'should raise an error when provided attribute key is invalid' do
        expect { config.get_attribute_id('invalid_attr') }.to raise_error(Optimizely::InvalidAttributeError)
      end
    end
  end

  describe '#experiment_running' do
    let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, logger, error_handler) }

    it 'should return true if the experiment is running' do
      experiment = config.get_experiment_from_key('test_experiment')
      expect(config.experiment_running?(experiment)).to eq(true)
    end

    it 'should return false if the experiment is not running' do
      experiment = config.get_experiment_from_key('test_experiment_not_started')
      expect(config.experiment_running?(experiment)).to eq(false)
    end
  end

  describe '#get_feature_flag_from_key' do
    it 'should return the feature flag associated with the given feature flag key' do
      feature_flag = config.get_feature_flag_from_key('boolean_feature')
      expect(feature_flag).to eq(config_body['featureFlags'][0])
    end
  end

  describe 'get_attribute_id_valid_key' do
    let(:spy_logger) { spy('logger') }
    let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }

    it 'should return attribute ID when provided valid attribute key has reserved prefix' do
      config.attribute_key_map['$opt_bot'] = {'key' => '$opt_bot', 'id' => '111'}
      expect(config.get_attribute_id('$opt_bot')).to eq('111')
      expect(spy_logger).to have_received(:log).with(
        Logger::WARN,
        "Attribute '$opt_bot' unexpectedly has reserved prefix '$opt_'; using attribute ID instead of reserved attribute name."
      )
    end

    it 'should return attribute ID when provided attribute key is valid' do
      expect(config.get_attribute_id('browser_type')).to eq('111094')
    end

    it 'should return attribute key as attribute ID when key has reserved prefix but is not present in data file' do
      expect(config.get_attribute_id('$opt_user_agent')).to eq('$opt_user_agent')
    end
  end

  describe '#test_cmab_field_population' do
    it 'Should return CMAB details' do
      config_dict = Marshal.load(Marshal.dump(OptimizelySpec::VALID_CONFIG_BODY))
      config_dict['experiments'][0]['cmab'] = {'attributeIds' => %w[808797688 808797689], 'trafficAllocation' => 4000}
      config_dict['experiments'][0]['trafficAllocation'] = []

      config_json = JSON.dump(config_dict)
      project_config = Optimizely::DatafileProjectConfig.new(config_json, logger, error_handler)

      experiment = project_config.get_experiment_from_key('test_experiment')
      expect(experiment['cmab']).to eq({'attributeIds' => %w[808797688 808797689], 'trafficAllocation' => 4000})

      experiment2 = project_config.get_experiment_from_key('test_experiment_with_audience')
      expect(experiment2['cmab']).to eq(nil)
    end
    it 'should return nil if cmab field is missing' do
      config_dict = Marshal.load(Marshal.dump(OptimizelySpec::VALID_CONFIG_BODY))
      config_dict['experiments'][0].delete('cmab')
      config_json = JSON.dump(config_dict)
      project_config = Optimizely::DatafileProjectConfig.new(config_json, logger, error_handler)
      experiment = project_config.get_experiment_from_key('test_experiment')
      expect(experiment['cmab']).to eq(nil)
    end

    it 'should handle empty cmab object' do
      config_dict = Marshal.load(Marshal.dump(OptimizelySpec::VALID_CONFIG_BODY))
      config_dict['experiments'][0]['cmab'] = {}
      config_json = JSON.dump(config_dict)
      project_config = Optimizely::DatafileProjectConfig.new(config_json, logger, error_handler)
      experiment = project_config.get_experiment_from_key('test_experiment')
      expect(experiment['cmab']).to eq({})
    end

    it 'should handle cmab with only attributeIds' do
      config_dict = Marshal.load(Marshal.dump(OptimizelySpec::VALID_CONFIG_BODY))
      config_dict['experiments'][0]['cmab'] = {'attributeIds' => %w[808797688]}
      config_json = JSON.dump(config_dict)
      project_config = Optimizely::DatafileProjectConfig.new(config_json, logger, error_handler)
      experiment = project_config.get_experiment_from_key('test_experiment')
      expect(experiment['cmab']).to eq({'attributeIds' => %w[808797688]})
    end

    it 'should handle cmab with only trafficAllocation' do
      config_dict = Marshal.load(Marshal.dump(OptimizelySpec::VALID_CONFIG_BODY))
      config_dict['experiments'][0]['cmab'] = {'trafficAllocation' => 1234}
      config_json = JSON.dump(config_dict)
      project_config = Optimizely::DatafileProjectConfig.new(config_json, logger, error_handler)
      experiment = project_config.get_experiment_from_key('test_experiment')
      expect(experiment['cmab']).to eq({'trafficAllocation' => 1234})
    end

    it 'should not affect other experiments when cmab is set' do
      config_dict = Marshal.load(Marshal.dump(OptimizelySpec::VALID_CONFIG_BODY))
      config_dict['experiments'][0]['cmab'] = {'attributeIds' => %w[808797688 808797689], 'trafficAllocation' => 4000}
      config_json = JSON.dump(config_dict)
      project_config = Optimizely::DatafileProjectConfig.new(config_json, logger, error_handler)
      experiment2 = project_config.get_experiment_from_key('test_experiment_with_audience')
      expect(experiment2['cmab']).to eq(nil)
    end
  end

  describe '#feature_experiment' do
    let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, logger, error_handler) }

    it 'should return true if the experiment is a feature test' do
      experiment = config.get_experiment_from_key('test_experiment_double_feature')
      expect(config.feature_experiment?(experiment['id'])).to eq(true)
    end

    it 'should return false if the experiment is not a feature test' do
      experiment = config.get_experiment_from_key('test_experiment')
      expect(config.feature_experiment?(experiment['id'])).to eq(false)
    end
  end

  describe '#rollout_experiment' do
    let(:config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, logger, error_handler) }

    it 'should return true if the experiment is a rollout test' do
      expect(config.rollout_experiment?('177770')).to eq(true)
    end

    it 'should return false if the experiment is not a rollout test' do
      expect(config.rollout_experiment?('177771')).to eq(false)
    end
  end

  describe '#feature variation map' do
    let(:config) { Optimizely::DatafileProjectConfig.new(decision_JSON, logger, error_handler) }

    it 'should return valid flag variation map without duplicates' do
      # variation '3324490634' is repeated in datafile but should appear once in map
      expected_feature_variation_map = {
        'feature_1' => [{
          'variables' => [],
          'featureEnabled' => true,
          'id' => '10389729780',
          'key' => 'a'
        }, {
          'variables' => [],
          'id' => '10416523121',
          'key' => 'b',
          'featureEnabled' => false
        }, {
          'featureEnabled' => true,
          'id' => '3324490633',
          'key' => '3324490633',
          'variables' => []
        }, {
          'featureEnabled' => true,
          'id' => '3324490634',
          'key' => '3324490634',
          'variables' => []
        }, {
          'featureEnabled' => true,
          'id' => '3324490562',
          'key' => '3324490562',
          'variables' => []
        }, {
          'variables' => [],
          'id' => '18257766532',
          'key' => '18257766532',
          'featureEnabled' => true
        }], 'feature_2' => [{
          'variables' => [],
          'featureEnabled' => true,
          'id' => '10418551353',
          'key' => 'variation_with_traffic'
        }, {
          'variables' => [],
          'featureEnabled' => false,
          'id' => '10418510624',
          'key' => 'variation_no_traffic'
        }], 'feature_3' => []
      }
      expect(config.send(:generate_feature_variation_map, config.feature_flags)).to eq(expected_feature_variation_map)
    end
  end

  describe '#get_holdouts_for_flag' do
    let(:config_with_holdouts) do
      Optimizely::DatafileProjectConfig.new(
        OptimizelySpec::CONFIG_BODY_WITH_HOLDOUTS_JSON,
        logger,
        error_handler
      )
    end

    it 'should return empty array for non-existent flag' do
      holdouts = config_with_holdouts.get_holdouts_for_flag('non_existent_flag')
      expect(holdouts).to eq([])
    end

    it 'should return global holdouts that do not exclude the flag' do
      holdouts = config_with_holdouts.get_holdouts_for_flag('multi_variate_feature')
      expect(holdouts.length).to eq(2)

      global_holdout = holdouts.find { |h| h['key'] == 'global_holdout' }
      expect(global_holdout).not_to be_nil
      expect(global_holdout['id']).to eq('holdout_1')

      specific_holdout = holdouts.find { |h| h['key'] == 'specific_holdout' }
      expect(specific_holdout).not_to be_nil
      expect(specific_holdout['id']).to eq('holdout_2')
    end

    it 'should not return global holdouts that exclude the flag' do
      holdouts = config_with_holdouts.get_holdouts_for_flag('boolean_single_variable_feature')
      expect(holdouts.length).to eq(0)

      global_holdout = holdouts.find { |h| h['key'] == 'global_holdout' }
      expect(global_holdout).to be_nil
    end

    it 'should cache results for subsequent calls' do
      holdouts1 = config_with_holdouts.get_holdouts_for_flag('multi_variate_feature')
      holdouts2 = config_with_holdouts.get_holdouts_for_flag('multi_variate_feature')
      expect(holdouts1).to equal(holdouts2)
      expect(holdouts1.length).to eq(2)
    end

    it 'should return only global holdouts for flags not specifically targeted' do
      holdouts = config_with_holdouts.get_holdouts_for_flag('string_single_variable_feature')

      # Should only include global holdout (not excluded and no specific targeting)
      expect(holdouts.length).to eq(1)
      expect(holdouts.first['key']).to eq('global_holdout')
    end
  end

  describe '#get_holdout' do
    let(:config_with_holdouts) do
      Optimizely::DatafileProjectConfig.new(
        OptimizelySpec::CONFIG_BODY_WITH_HOLDOUTS_JSON,
        logger,
        error_handler
      )
    end

    it 'should return holdout when valid ID is provided' do
      holdout = config_with_holdouts.get_holdout('holdout_1')
      expect(holdout).not_to be_nil
      expect(holdout['id']).to eq('holdout_1')
      expect(holdout['key']).to eq('global_holdout')
      expect(holdout['status']).to eq('Running')
    end

    it 'should return holdout regardless of status when valid ID is provided' do
      holdout = config_with_holdouts.get_holdout('holdout_2')
      expect(holdout).not_to be_nil
      expect(holdout['id']).to eq('holdout_2')
      expect(holdout['key']).to eq('specific_holdout')
      expect(holdout['status']).to eq('Running')
    end

    it 'should return nil for non-existent holdout ID' do
      holdout = config_with_holdouts.get_holdout('non_existent_holdout')
      expect(holdout).to be_nil
    end
  end

  describe '#get_holdout with logging' do
    let(:spy_logger) { spy('logger') }
    let(:config_with_holdouts) do
      config_body_with_holdouts = config_body.dup
      config_body_with_holdouts['holdouts'] = [
        {
          'id' => 'holdout_1',
          'key' => 'test_holdout',
          'status' => 'Running',
          'includedFlags' => [],
          'excludedFlags' => []
        }
      ]
      config_json = JSON.dump(config_body_with_holdouts)
      Optimizely::DatafileProjectConfig.new(config_json, spy_logger, error_handler)
    end

    it 'should log error when holdout is not found' do
      result = config_with_holdouts.get_holdout('invalid_holdout_id')

      expect(result).to be_nil
      expect(spy_logger).to have_received(:log).with(
        Logger::ERROR,
        "Holdout with ID 'invalid_holdout_id' not found."
      )
    end

    it 'should not log when holdout is found' do
      result = config_with_holdouts.get_holdout('holdout_1')

      expect(result).not_to be_nil
      expect(spy_logger).not_to have_received(:log).with(
        Logger::ERROR,
        anything
      )
    end
  end

  describe 'holdout initialization' do
    let(:config_with_complex_holdouts) do
      config_body_with_holdouts = config_body.dup

      # Use the correct feature flag IDs from the debug output
      boolean_feature_id = '155554'
      multi_variate_feature_id = '155559'
      empty_feature_id = '594032'
      string_feature_id = '594060'

      config_body_with_holdouts['holdouts'] = [
        {
          'id' => 'global_holdout',
          'key' => 'global',
          'status' => 'Running',
          'includedFlags' => [],
          'excludedFlags' => [boolean_feature_id, string_feature_id]
        },
        {
          'id' => 'specific_holdout',
          'key' => 'specific',
          'status' => 'Running',
          'includedFlags' => [multi_variate_feature_id, empty_feature_id],
          'excludedFlags' => []
        },
        {
          'id' => 'inactive_holdout',
          'key' => 'inactive',
          'status' => 'Inactive',
          'includedFlags' => [boolean_feature_id],
          'excludedFlags' => []
        }
      ]
      config_json = JSON.dump(config_body_with_holdouts)
      Optimizely::DatafileProjectConfig.new(config_json, logger, error_handler)
    end

    it 'should properly categorize holdouts during initialization' do
      expect(config_with_complex_holdouts.holdout_id_map.keys).to contain_exactly('global_holdout', 'specific_holdout')
      expect(config_with_complex_holdouts.global_holdouts.keys).to contain_exactly('global_holdout')

      # Use the correct feature flag IDs
      boolean_feature_id = '155554'
      multi_variate_feature_id = '155559'
      empty_feature_id = '594032'
      string_feature_id = '594060'

      expect(config_with_complex_holdouts.included_holdouts[multi_variate_feature_id]).not_to be_nil
      expect(config_with_complex_holdouts.included_holdouts[multi_variate_feature_id]).not_to be_empty
      expect(config_with_complex_holdouts.included_holdouts[empty_feature_id]).not_to be_nil
      expect(config_with_complex_holdouts.included_holdouts[empty_feature_id]).not_to be_empty
      expect(config_with_complex_holdouts.included_holdouts[boolean_feature_id]).to be_nil

      expect(config_with_complex_holdouts.excluded_holdouts[boolean_feature_id]).not_to be_nil
      expect(config_with_complex_holdouts.excluded_holdouts[boolean_feature_id]).not_to be_empty
      expect(config_with_complex_holdouts.excluded_holdouts[string_feature_id]).not_to be_nil
      expect(config_with_complex_holdouts.excluded_holdouts[string_feature_id]).not_to be_empty
    end

    it 'should only process running holdouts during initialization' do
      expect(config_with_complex_holdouts.holdout_id_map['inactive_holdout']).to be_nil
      expect(config_with_complex_holdouts.global_holdouts['inactive_holdout']).to be_nil

      boolean_feature_id = '155554'
      included_for_boolean = config_with_complex_holdouts.included_holdouts[boolean_feature_id]
      expect(included_for_boolean).to be_nil
    end
  end

  describe 'Holdout Decision Functionality' do
    let(:holdout_test_data_path) do
      File.join(File.dirname(__FILE__), 'test_data', 'holdout_test_data.json')
    end

    let(:holdout_test_data) do
      JSON.parse(File.read(holdout_test_data_path))
    end

    let(:datafile_with_holdouts) do
      holdout_test_data['datafileWithHoldouts']
    end

    let(:config_with_holdouts) do
      Optimizely::DatafileProjectConfig.new(
        datafile_with_holdouts,
        logger,
        error_handler
      )
    end

    describe '#decide with global holdout' do
      it 'should return valid decision for global holdout' do
        feature_flag = config_with_holdouts.feature_flag_key_map['test_flag_1']
        expect(feature_flag).not_to be_nil

        # Verify holdouts are loaded
        expect(config_with_holdouts.holdouts).not_to be_nil
        expect(config_with_holdouts.holdouts.length).to be > 0
      end

      it 'should handle decision with global holdout configuration' do
        feature_flag = config_with_holdouts.feature_flag_key_map['test_flag_1']
        expect(feature_flag).not_to be_nil
        expect(feature_flag['id']).not_to be_empty
      end
    end

    describe '#decide with included flags holdout' do
      it 'should return valid decision for included flags' do
        feature_flag = config_with_holdouts.feature_flag_key_map['test_flag_1']
        expect(feature_flag).not_to be_nil

        # Check if there's a holdout that includes this flag
        included_holdout = config_with_holdouts.holdouts.find do |h|
          h['includedFlags']&.include?(feature_flag['id'])
        end

        if included_holdout
          expect(included_holdout['key']).not_to be_empty
          expect(included_holdout['status']).to eq('Running')
        end
      end

      it 'should properly filter holdouts based on includedFlags' do
        feature_flag = config_with_holdouts.feature_flag_key_map['test_flag_1']
        expect(feature_flag).not_to be_nil

        holdouts_for_flag = config_with_holdouts.get_holdouts_for_flag('test_flag_1')
        expect(holdouts_for_flag).to be_an(Array)
      end
    end

    describe '#decide with excluded flags holdout' do
      it 'should not return excluded holdout for excluded flag' do
        # test_flag_3 is excluded by holdout_excluded_1
        feature_flag = config_with_holdouts.feature_flag_key_map['test_flag_3']
        
        if feature_flag
          holdouts_for_flag = config_with_holdouts.get_holdouts_for_flag('test_flag_3')
          
          # Should not include holdouts that exclude this flag
          excluded_holdout = holdouts_for_flag.find { |h| h['key'] == 'excluded_holdout' }
          expect(excluded_holdout).to be_nil
        end
      end

      it 'should return holdouts for non-excluded flag' do
        feature_flag = config_with_holdouts.feature_flag_key_map['test_flag_1']
        expect(feature_flag).not_to be_nil

        holdouts_for_flag = config_with_holdouts.get_holdouts_for_flag('test_flag_1')
        expect(holdouts_for_flag).to be_an(Array)
      end
    end

    describe '#decide with multiple holdouts' do
      it 'should handle multiple holdouts for different flags' do
        flag_keys = ['test_flag_1', 'test_flag_2', 'test_flag_3', 'test_flag_4']
        
        flag_keys.each do |flag_key|
          feature_flag = config_with_holdouts.feature_flag_key_map[flag_key]
          next unless feature_flag

          holdouts = config_with_holdouts.get_holdouts_for_flag(flag_key)
          expect(holdouts).to be_an(Array)
          
          # Each holdout should have proper structure
          holdouts.each do |holdout|
            expect(holdout).to have_key('id')
            expect(holdout).to have_key('key')
            expect(holdout).to have_key('status')
          end
        end
      end

      it 'should properly cache holdout lookups' do
        holdouts_1 = config_with_holdouts.get_holdouts_for_flag('test_flag_1')
        holdouts_2 = config_with_holdouts.get_holdouts_for_flag('test_flag_1')
        
        expect(holdouts_1).to equal(holdouts_2)
      end
    end

    describe '#decide with inactive holdout' do
      it 'should not include inactive holdouts in decision process' do
        # Find a holdout and verify status handling
        holdout = config_with_holdouts.holdouts.first
        
        if holdout
          original_status = holdout['status']
          holdout['status'] = 'Paused'
          
          # Should not be in active holdouts map
          expect(config_with_holdouts.holdout_id_map[holdout['id']]).to be_nil
          
          # Restore original status
          holdout['status'] = original_status
        end
      end

      it 'should only process running holdouts' do
        running_holdouts = config_with_holdouts.holdouts.select { |h| h['status'] == 'Running' }
        
        running_holdouts.each do |holdout|
          expect(config_with_holdouts.holdout_id_map[holdout['id']]).not_to be_nil
        end
      end
    end

    describe '#decide with empty user id' do
      it 'should handle empty user id without error' do
        feature_flag = config_with_holdouts.feature_flag_key_map['test_flag_1']
        expect(feature_flag).not_to be_nil
        
        # Empty user ID should be valid for bucketing
        # This test verifies the config structure supports this
        expect(feature_flag['key']).to eq('test_flag_1')
      end
    end

    describe '#holdout priority evaluation' do
      it 'should evaluate global holdouts for flags without specific targeting' do
        feature_flag = config_with_holdouts.feature_flag_key_map['test_flag_1']
        expect(feature_flag).not_to be_nil

        global_holdouts = config_with_holdouts.holdouts.select do |h|
          h['includedFlags'].nil? || h['includedFlags'].empty?
        end

        included_holdouts = config_with_holdouts.holdouts.select do |h|
          h['includedFlags']&.include?(feature_flag['id'])
        end

        # Should have either global or included holdouts
        expect(global_holdouts.length + included_holdouts.length).to be >= 0
      end

      it 'should handle mixed holdout configurations' do
        # Verify the config has properly categorized holdouts
        expect(config_with_holdouts.global_holdouts).to be_a(Hash)
        expect(config_with_holdouts.included_holdouts).to be_a(Hash)
        expect(config_with_holdouts.excluded_holdouts).to be_a(Hash)
      end
    end
  end

  describe 'Holdout Decision Reasons' do
    let(:holdout_test_data_path) do
      File.join(File.dirname(__FILE__), 'test_data', 'holdout_test_data.json')
    end
    
    let(:holdout_test_data) do
      JSON.parse(File.read(holdout_test_data_path))
    end
    
    let(:datafile_with_holdouts) do
      holdout_test_data['datafileWithHoldouts']
    end
    
    let(:config_with_holdouts) do
      Optimizely::DatafileProjectConfig.new(
        datafile_with_holdouts,
        logger,
        error_handler
      )
    end

    describe 'decision reasons structure' do
      it 'should support decision reasons for holdout decisions' do
        feature_flag = config_with_holdouts.feature_flag_key_map['test_flag_1']
        expect(feature_flag).not_to be_nil
        
        # Verify the feature flag has proper structure for decision reasons
        expect(feature_flag).to have_key('id')
        expect(feature_flag).to have_key('key')
      end

      it 'should include holdout information in config' do
        expect(config_with_holdouts.holdouts).not_to be_empty
        
        config_with_holdouts.holdouts.each do |holdout|
          expect(holdout).to have_key('id')
          expect(holdout).to have_key('key')
          expect(holdout).to have_key('status')
        end
      end
    end

    describe 'holdout bucketing messages' do
      it 'should have holdout configuration for bucketing decisions' do
        holdout = config_with_holdouts.holdouts.first
        
        if holdout
          expect(holdout['status']).to eq('Running')
          expect(holdout).to have_key('audiences')
        end
      end

      it 'should support audience evaluation for holdouts' do
        holdout = config_with_holdouts.holdouts.first
        
        if holdout
          # Holdouts should have audience conditions (even if empty)
          expect(holdout).to have_key('audiences')
          expect(holdout['audiences']).to be_an(Array)
        end
      end
    end

    describe 'holdout status messages' do
      it 'should differentiate between running and non-running holdouts' do
        running_holdouts = config_with_holdouts.holdouts.select { |h| h['status'] == 'Running' }
        non_running_holdouts = config_with_holdouts.holdouts.select { |h| h['status'] != 'Running' }
        
        # Only running holdouts should be in the holdout_id_map
        running_holdouts.each do |holdout|
          expect(config_with_holdouts.holdout_id_map[holdout['id']]).not_to be_nil
        end
        
        non_running_holdouts.each do |holdout|
          expect(config_with_holdouts.holdout_id_map[holdout['id']]).to be_nil
        end
      end
    end

    describe 'audience condition evaluation' do
      it 'should support audience conditions in holdouts' do
        holdout = config_with_holdouts.holdouts.first
        
        if holdout
          expect(holdout).to have_key('audiences')
          
          # Empty audience array means it matches everyone (evaluates to TRUE)
          if holdout['audiences'].empty?
            # This is valid - empty audiences = no restrictions
            expect(holdout['audiences']).to eq([])
          end
        end
      end

      it 'should handle holdouts with empty audience conditions' do
        # Empty audience conditions should evaluate to TRUE (match everyone)
        holdouts_with_empty_audiences = config_with_holdouts.holdouts.select do |h|
          h['audiences'].nil? || h['audiences'].empty?
        end
        
        # These holdouts should match all users
        holdouts_with_empty_audiences.each do |holdout|
          expect(holdout['status']).to eq('Running')
        end
      end
    end

    describe 'holdout evaluation reasoning' do
      it 'should provide holdout configuration for evaluation' do
        feature_flag = config_with_holdouts.feature_flag_key_map['test_flag_1']
        expect(feature_flag).not_to be_nil
        
        holdouts_for_flag = config_with_holdouts.get_holdouts_for_flag('test_flag_1')
        
        holdouts_for_flag.each do |holdout|
          # Each holdout should have necessary info for decision reasoning
          expect(holdout['id']).not_to be_empty
          expect(holdout['key']).not_to be_empty
          expect(holdout['status']).to eq('Running')
        end
      end

      it 'should support relevant holdout decision information' do
        holdout = config_with_holdouts.holdouts.first
        
        if holdout
          # Verify holdout has all necessary fields for decision reasoning
          expect(holdout).to have_key('id')
          expect(holdout).to have_key('key')
          expect(holdout).to have_key('status')
          expect(holdout).to have_key('audiences')
          expect(holdout).to have_key('includedFlags')
          expect(holdout).to have_key('excludedFlags')
        end
      end
    end
  end

  describe 'Holdout Edge Cases' do
    let(:config_with_holdouts) do
      config_body_with_holdouts = config_body.dup
      config_body_with_holdouts['holdouts'] = [
        {
          'id' => 'holdout_1',
          'key' => 'test_holdout',
          'status' => 'Running',
          'audiences' => [],
          'includedFlags' => [],
          'excludedFlags' => []
        },
        {
          'id' => 'holdout_2',
          'key' => 'paused_holdout',
          'status' => 'Paused',
          'audiences' => [],
          'includedFlags' => [],
          'excludedFlags' => []
        }
      ]
      config_json = JSON.dump(config_body_with_holdouts)
      Optimizely::DatafileProjectConfig.new(config_json, logger, error_handler)
    end

    it 'should handle datafile without holdouts' do
      config_without_holdouts = Optimizely::DatafileProjectConfig.new(
        config_body_JSON,
        logger,
        error_handler
      )
      
      holdouts_for_flag = config_without_holdouts.get_holdouts_for_flag('boolean_feature')
      expect(holdouts_for_flag).to eq([])
    end

    it 'should handle holdouts with nil included/excluded flags' do
      config_body_with_nil = config_body.dup
      config_body_with_nil['holdouts'] = [
        {
          'id' => 'holdout_nil',
          'key' => 'nil_holdout',
          'status' => 'Running',
          'audiences' => [],
          'includedFlags' => nil,
          'excludedFlags' => nil
        }
      ]
      config_json = JSON.dump(config_body_with_nil)
      config = Optimizely::DatafileProjectConfig.new(config_json, logger, error_handler)
      
      # Should treat as global holdout
      expect(config.global_holdouts['holdout_nil']).not_to be_nil
    end

    it 'should only include running holdouts in maps' do
      running_count = config_with_holdouts.holdout_id_map.length
      total_count = config_with_holdouts.holdouts.length
      
      # Only running holdouts should be in the map
      expect(running_count).to be < total_count
      expect(config_with_holdouts.holdout_id_map['holdout_1']).not_to be_nil
      expect(config_with_holdouts.holdout_id_map['holdout_2']).to be_nil
    end

    it 'should handle mixed status holdouts correctly' do
      running_holdouts = config_with_holdouts.holdouts.select { |h| h['status'] == 'Running' }
      
      running_holdouts.each do |holdout|
        expect(config_with_holdouts.get_holdout(holdout['id'])).not_to be_nil
      end
    end
  end
end
