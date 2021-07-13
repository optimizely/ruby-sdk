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
        expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Event 'invalid_key' is not in datafile.")
      end
    end

    describe 'get_audience_from_id' do
      it 'should log a message when provided audience ID is invalid' do
        config.get_audience_from_id('invalid_id')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Audience 'invalid_id' is not in datafile.")
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
        expect(config.get_variation_from_id_by_experiment_id('test_experiment', 'invalid_variation')).to eq(nil)
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

    describe 'get_variation_from_key_by_experiment_id' do
      it 'should log a message when provided experiment id is invalid' do
        config.get_variation_from_key_by_experiment_id('invalid_id', 'some_variation')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment id 'invalid_id' is not in datafile.")
      end
      it 'should return nil when provided variation id is invalid' do
        expect(config.get_variation_from_key_by_experiment_id('test_experiment', 'invalid_variation')).to eq(nil)
      end

      it 'should return variation having featureEnabled false when not provided in the datafile' do
        config_body = OptimizelySpec::VALID_CONFIG_BODY
        experiment_id = config_body['experiments'][1]['id']
        variation_key = config_body['experiments'][1]['variations'][1]['key']

        config_body['experiments'][1]['variations'][1][feature_enabled] = nil

        config_body_json = JSON.dump(config_body)
        project_config = Optimizely::DatafileProjectConfig.new(config_body_json, logger, error_handler)

        expect(project_config.get_variation_from_key_by_experiment_id(experiment_id, variation_key)[feature_enabled]).to eq(false)
      end
    end

    describe 'get_variation_id_from_key' do
      it 'should log a message when there is no variation key map for the experiment' do
        config.get_variation_id_from_key('invalid_key', 'invalid_variation')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment key 'invalid_key' is not in datafile.")
      end
    end

    describe 'get_whitelisted_variations' do
      it 'should log a message when there is no experiment key map for the experiment' do
        config.get_whitelisted_variations('invalid_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment key 'invalid_key' is not in datafile.")
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
end
