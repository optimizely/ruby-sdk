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

require 'spec_helper'

describe Optimizely::OptimizelyConfig do
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:similar_exp_keys_JSON) { OptimizelySpec::SIMILAR_EXP_KEYS_JSON }
  let(:typed_audiences_JSON) { OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES_JSON }
  let(:similar_rule_key_JSON) { OptimizelySpec::SIMILAR_RULE_KEYS_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:project_instance) { Optimizely::Project.new(config_body_JSON, nil, spy_logger, error_handler, false, nil, nil, nil, nil, nil, [], nil, {disable_odp: true}) }
  let(:optimizely_config) { project_instance.get_optimizely_config }
  let(:project_config_sim_keys) { Optimizely::DatafileProjectConfig.new(similar_exp_keys_JSON, spy_logger, error_handler) }
  let(:project_instance_sim_keys) { Optimizely::Project.new(similar_exp_keys_JSON, nil, spy_logger, error_handler, false, nil, nil, nil, nil, nil, [], nil, {disable_odp: true}) }
  let(:optimizely_config_sim_keys) { project_instance_sim_keys.get_optimizely_config }
  let(:project_config_typed_audiences) { Optimizely::DatafileProjectConfig.new(typed_audiences_JSON, spy_logger, error_handler) }
  let(:project_instance_typed_audiences) { Optimizely::Project.new(typed_audiences_JSON, nil, spy_logger, error_handler, false, nil, nil, nil, nil, nil, [], nil, {disable_odp: true}) }
  let(:optimizely_config_typed_audiences) { project_instance_typed_audiences.get_optimizely_config }
  let(:project_config_similar_rule_keys) { Optimizely::DatafileProjectConfig.new(similar_rule_key_JSON, spy_logger, error_handler) }
  let(:project_instance_similar_rule_keys) { Optimizely::Project.new(similar_rule_key_JSON, nil, spy_logger, error_handler, false, nil, nil, nil, nil, nil, [], nil, {disable_odp: true}) }
  let(:optimizely_config_similar_rule_keys) { project_instance_similar_rule_keys.get_optimizely_config }

  it 'should return all experiments' do
    experiments_map = optimizely_config['experimentsMap']
    expect(experiments_map.length).to eq(11)

    expected_experiment_map = {
      'group1_exp1' => {
        'audiences' => '', 'variationsMap' => {
          'g1_e1_v1' => {
            'variablesMap' => {
              'correlating_variation_name' => {
                'id' => '155563', 'key' => 'correlating_variation_name',
                'type' => 'string', 'value' => 'groupie_1_v1'
              }
            }
          }, 'g1_e1_v2' => {
            'variablesMap' => {
              'correlating_variation_name' => {
                'id' => '155563', 'key' => 'correlating_variation_name',
                'type' => 'string', 'value' => 'groupie_1_v2'
              }
            }
          }
        }
      },
      'group1_exp2' => {
        'audiences' => '', 'variationsMap' => {
          'g1_e2_v1' => {
            'variablesMap' => {
              'correlating_variation_name' => {
                'id' => '155563', 'key' => 'correlating_variation_name',
                'type' => 'string', 'value' => 'groupie_2_v1'
              }
            }
          }, 'g1_e2_v2' => {
            'variablesMap' => {
              'correlating_variation_name' => {
                'id' => '155563', 'key' => 'correlating_variation_name',
                'type' => 'string', 'value' => 'groupie_2_v2'
              }
            }
          }
        }
      },
      'group2_exp1' => {
        'audiences' => '', 'variationsMap' => {
          'g2_e1_v1' => {
            'variablesMap' => {}
          }, 'g2_e1_v2' => {
            'variablesMap' => {}
          }
        }
      },
      'group2_exp2' => {
        'audiences' => '', 'variationsMap' => {
          'g2_e2_v1' => {
            'variablesMap' => {}
          }, 'g2_e2_v2' => {
            'variablesMap' => {}
          }
        }
      },
      'test_experiment' => {
        'audiences' => '', 'variationsMap' => {
          'control' => {
            'variablesMap' => {}
          }, 'variation' => {
            'variablesMap' => {}
          }
        }
      },
      'test_experiment_double_feature' => {
        'audiences' => '', 'variationsMap' => {
          'control' => {
            'variablesMap' => {
              'double_variable' => {
                'id' => '155551', 'key' => 'double_variable', 'type' =>
                  'double', 'value' => '42.42'
              }
            }
          }, 'variation' => {
            'variablesMap' => {
              'double_variable' => {
                'id' => '155551', 'key' => 'double_variable', 'type' =>
                  'double', 'value' => '13.37'
              }
            }
          }
        }
      },
      'test_experiment_integer_feature' => {
        'audiences' => '', 'variationsMap' => {
          'control' => {
            'variablesMap' => {
              'integer_variable' => {
                'id' => '155553', 'key' => 'integer_variable', 'type' =>
                  'integer', 'value' => '42'
              }
            }
          }, 'variation' => {
            'variablesMap' => {
              'integer_variable' => {
                'id' => '155553', 'key' => 'integer_variable', 'type' =>
                  'integer', 'value' => '13'
              }
            }
          }
        }
      },
      'test_experiment_multivariate' => {
        'audiences' => '', 'variationsMap' => {
          'Feorge' => {
            'variablesMap' => {
              'first_letter' => {
                'id' => '155560', 'key' => 'first_letter', 'type' =>
                  'string', 'value' => 'H'
              }, 'rest_of_name' => {
                'id' => '155561', 'key' => 'rest_of_name', 'type' =>
                  'string', 'value' => 'arry'
              }
            }
          }, 'Fred' => {
            'variablesMap' => {
              'first_letter' => {
                'id' => '155560', 'key' => 'first_letter', 'type' =>
                  'string', 'value' => 'F'
              }, 'rest_of_name' => {
                'id' => '155561', 'key' => 'rest_of_name', 'type' =>
                  'string', 'value' => 'red'
              }
            }
          }, 'George' => {
            'variablesMap' => {
              'first_letter' => {
                'id' => '155560', 'key' => 'first_letter', 'type' =>
                  'string', 'value' => 'G'
              }, 'rest_of_name' => {
                'id' => '155561', 'key' => 'rest_of_name', 'type' =>
                  'string', 'value' => 'eorge'
              }
            }
          }, 'Gred' => {
            'variablesMap' => {
              'first_letter' => {
                'id' => '155560', 'key' => 'first_letter', 'type' =>
                  'string', 'value' => 'G'
              }, 'rest_of_name' => {
                'id' => '155561', 'key' => 'rest_of_name', 'type' =>
                  'string', 'value' => 'red'
              }
            }
          }
        }
      },
      'test_experiment_not_started' => {
        'audiences' => '', 'variationsMap' => {
          'control_not_started' => {
            'variablesMap' => {}
          }, 'variation_not_started' => {
            'variablesMap' => {}
          }
        }
      },
      'test_experiment_with_audience' => {
        'audiences' => '', 'variationsMap' => {
          'control_with_audience' => {
            'variablesMap' => {}
          }, 'variation_with_audience' => {
            'variablesMap' => {}
          }
        }
      },
      'test_experiment_with_feature_rollout' => {
        'audiences' => '', 'variationsMap' => {
          'control' => {
            'variablesMap' => {
              'string_variable' => {
                'id' => '155558', 'key' => 'string_variable', 'type' =>
                  'string', 'value' => 'cta_1'
              }
            }
          }, 'variation' => {
            'variablesMap' => {
              'string_variable' => {
                'id' => '155558', 'key' => 'string_variable', 'type' =>
                  'string', 'value' => 'cta_2'
              }
            }
          }
        }
      }
    }
    project_config.experiments.each do |experiment|
      expect(experiments_map[experiment['key']]).to include(
        'id' => experiment['id'],
        'key' => experiment['key'],
        'audiences' => expected_experiment_map[experiment['key']]['audiences']
      )
      variations_map = experiments_map[experiment['key']]['variationsMap']
      experiment['variations'].each do |variation|
        expect(variations_map[variation['key']]).to include(
          'id' => variation['id'],
          'key' => variation['key'],
          'variablesMap' => expected_experiment_map[experiment['key']]['variationsMap'][variation['key']]['variablesMap']
        )
      end
    end
  end

  it 'should return correct experiment ids with similar keys' do
    experiments_map = optimizely_config_sim_keys['experimentsMap']
    expect(experiments_map.length).to eq(1)

    experiment_map_flag_1 = optimizely_config_sim_keys['featuresMap']['flag1']['experimentsMap']
    experiment_map_flag_2 = optimizely_config_sim_keys['featuresMap']['flag2']['experimentsMap']

    expect(experiment_map_flag_1['targeted_delivery']['id']).to eq('9300000007569')
    expect(experiment_map_flag_2['targeted_delivery']['id']).to eq('9300000007573')
  end

  it 'should return all events' do
    events = optimizely_config['events']
    expected_events = [{'experimentIds' => %w[111127 122230], 'id' => '111095', 'key' => 'test_event'},
                       {'experimentIds' => ['111127'], 'id' => '111096', 'key' => 'Total Revenue'},
                       {'experimentIds' => ['122227'],
                        'id' => '111097',
                        'key' => 'test_event_with_audience'},
                       {'experimentIds' => ['100027'],
                        'id' => '111098',
                        'key' => 'test_event_not_running'}]
    expect(events).to eq(expected_events)
  end

  it 'should return all attributes' do
    attributes = optimizely_config['attributes']
    expected_attributes = [{'id' => '111094', 'key' => 'browser_type'},
                           {'id' => '111095', 'key' => 'boolean_key'},
                           {'id' => '111096', 'key' => 'integer_key'},
                           {'id' => '111097', 'key' => 'double_key'}]
    expect(attributes).to eq(expected_attributes)
  end

  it 'should return all experiments in typed audiences' do
    experiments_map = optimizely_config_typed_audiences['experimentsMap']
    expect(experiments_map.length).to eq(4)

    expected_experiment_map = {
      'audience_combinations_experiment' => {
        'audiences' =>
          '("exactString" OR "substringString") AND ("exists" OR "exactNumber" OR "gtNumber" OR "ltNumber" OR "exactBoolean")',
        'variationsMap' => {
          'A' => {
            'id' => '1423767504', 'key' => 'A', 'variablesMap' => {}
          }
        }
      },
      'feat2_with_var_test' => {
        'audiences' =>
          '("exactString" OR "substringString") AND ("exists" OR "exactNumber" OR "gtNumber" OR "ltNumber" OR "exactBoolean")',
        'variationsMap' => {
          'variation_2' => {
            'variablesMap' => {
              'z' => {
                'id' => '11535264367', 'key' => 'z', 'type' => 'integer',
                'value' => '150'
              }
            }
          }
        }
      },
      'feat_with_var_test' => {
        'audiences' => '', 'variationsMap' => {
          'variation_2' => {
            'variablesMap' => {
              'x' => {
                'id' => '11535264366', 'key' => 'x', 'type' => 'string',
                'value' => 'xyz'
              }
            }
          }
        }
      },
      'typed_audience_experiment' => {
        'audiences' => '', 'variationsMap' => {
          'A' => {
            'id' => '1423767503', 'key' => 'A', 'variablesMap' => {}
          }
        }
      }
    }
    project_config_typed_audiences.experiments.each do |experiment|
      expect(experiments_map[experiment['key']]).to include(
        'id' => experiment['id'],
        'key' => experiment['key'],
        'audiences' => expected_experiment_map[experiment['key']]['audiences']
      )
      variations_map = experiments_map[experiment['key']]['variationsMap']
      experiment['variations'].each do |variation|
        expect(variations_map[variation['key']]).to include(
          'id' => variation['id'],
          'key' => variation['key'],
          'variablesMap' => expected_experiment_map[experiment['key']]['variationsMap'][variation['key']]['variablesMap']
        )
      end
    end
  end

  it 'should return all rollouts with similar keys' do
    experiments_map = optimizely_config_similar_rule_keys['experimentsMap']
    expect(experiments_map.length).to eq(0)

    rollout_flag_1 = optimizely_config_similar_rule_keys['featuresMap']['flag_1']['deliveryRules'][0]
    rollout_flag_2 = optimizely_config_similar_rule_keys['featuresMap']['flag_2']['deliveryRules'][0]
    rollout_flag_3 = optimizely_config_similar_rule_keys['featuresMap']['flag_3']['deliveryRules'][0]

    expect(rollout_flag_1['id']).to eq('9300000004977')
    expect(rollout_flag_1['key']).to eq('targeted_delivery')
    expect(rollout_flag_2['id']).to eq('9300000004979')
    expect(rollout_flag_2['key']).to eq('targeted_delivery')
    expect(rollout_flag_3['id']).to eq('9300000004981')
    expect(rollout_flag_3['key']).to eq('targeted_delivery')
  end

  it 'should return all feature flags' do
    features_map = optimizely_config['featuresMap']
    expect(features_map.length).to eq(10)
    expected_features_map = {
      'all_variables_feature' => {
        'deliveryRules' => [], 'experimentRules' => []
      },
      'boolean_feature' => {
        'deliveryRules' => [], 'experimentRules' => [{
          'audiences' => '', 'id' => '122227', 'key' =>
            'test_experiment_with_audience', 'variationsMap' => {
              'control_with_audience' => {
                'featureEnabled' => true, 'id' => '122228', 'key' =>
                  'control_with_audience', 'variablesMap' => {}
              }, 'variation_with_audience' => {
                'featureEnabled' => true, 'id' => '122229', 'key' =>
                'variation_with_audience', 'variablesMap' => {}
              }
            }
        }]
      },
      'boolean_single_variable_feature' => {
        'deliveryRules' => [{
          'audiences' => '', 'id' => '177770', 'key' => '177770',
          'variationsMap' => {
            '177771' => {
              'featureEnabled' => true, 'id' => '177771', 'key' =>
                '177771', 'variablesMap' => {
                  'boolean_variable' => {
                    'id' => '155556', 'key' => 'boolean_variable',
                    'type' => 'boolean', 'value' => 'true'
                  }
                }
            }
          }
        }, {
          'audiences' => '', 'id' => '177772', 'key' => '177772',
          'variationsMap' => {
            '177773' => {
              'featureEnabled' => false, 'id' => '177773', 'key' =>
                '177773', 'variablesMap' => {
                  'boolean_variable' => {
                    'id' => '155556', 'key' => 'boolean_variable',
                    'type' => 'boolean', 'value' => 'true'
                  }
                }
            }
          }
        }, {
          'audiences' => '', 'id' => '177776', 'key' => '177776',
          'variationsMap' => {
            '177778' => {
              'featureEnabled' => true, 'id' => '177778', 'key' =>
                '177778', 'variablesMap' => {
                  'boolean_variable' => {
                    'id' => '155556', 'key' => 'boolean_variable',
                    'type' => 'boolean', 'value' => 'false'
                  }
                }
            }
          }
        }], 'experimentRules' => []
      },
      'double_single_variable_feature' => {
        'deliveryRules' => [], 'experimentRules' => [{
          'audiences' => '', 'id' => '122238', 'key' =>
            'test_experiment_double_feature', 'variationsMap' => {
              'control' => {
                'featureEnabled' => true, 'id' => '122239', 'key' =>
                  'control', 'variablesMap' => {
                    'double_variable' => {
                      'id' => '155551', 'key' => 'double_variable',
                      'type' => 'double', 'value' => '42.42'
                    }
                  }
              }, 'variation' => {
                'featureEnabled' => true, 'id' => '122240', 'key' =>
                'variation', 'variablesMap' => {
                  'double_variable' => {
                    'id' => '155551', 'key' => 'double_variable',
                    'type' => 'double', 'value' => '13.37'
                  }
                }
              }
            }
        }]
      },
      'empty_feature' => {
        'deliveryRules' => [], 'experimentRules' => []
      },
      'integer_single_variable_feature' => {
        'deliveryRules' => [], 'experimentRules' => [{
          'audiences' => '', 'id' => '122241', 'key' =>
            'test_experiment_integer_feature', 'variationsMap' => {
              'control' => {
                'featureEnabled' => true, 'id' => '122242', 'key' =>
                  'control', 'variablesMap' => {
                    'integer_variable' => {
                      'id' => '155553', 'key' => 'integer_variable',
                      'type' => 'integer', 'value' => '42'
                    }
                  }
              }, 'variation' => {
                'featureEnabled' => true, 'id' => '122243', 'key' =>
                'variation', 'variablesMap' => {
                  'integer_variable' => {
                    'id' => '155553', 'key' => 'integer_variable',
                    'type' => 'integer', 'value' => '13'
                  }
                }
              }
            }
        }]
      },
      'json_single_variable_feature' => {
        'deliveryRules' => [{
          'audiences' => '', 'id' => '177774', 'key' => '177774',
          'variationsMap' => {
            '177775' => {
              'featureEnabled' => true, 'id' => '177775', 'key' =>
                '177775', 'variablesMap' => {
                  'json_variable' => {
                    'id' => '1555588', 'key' => 'json_variable', 'type' =>
                      'json', 'value' =>
                      '{ "val": "wingardium leviosa" }'
                  }
                }
            }
          }
        }, {
          'audiences' => '', 'id' => '177779', 'key' => '177779',
          'variationsMap' => {
            '177780' => {
              'featureEnabled' => true, 'id' => '177780', 'key' =>
                '177780', 'variablesMap' => {
                  'json_variable' => {
                    'id' => '1555588', 'key' => 'json_variable', 'type' =>
                      'json', 'value' =>
                      '{ "val": "wingardium leviosa" }'
                  }
                }
            }
          }
        }, {
          'audiences' => '', 'id' => '177780', 'key' =>
            'rollout_exp_with_diff_id_and_key', 'variationsMap' => {
              'rollout_var_with_diff_id_and_key' => {
                'featureEnabled' => true, 'id' => '177781', 'key' =>
                  'rollout_var_with_diff_id_and_key', 'variablesMap' => {
                    'json_variable' => {
                      'id' => '1555588', 'key' => 'json_variable', 'type' =>
                        'json', 'value' =>
                        '{ "val": "wingardium leviosa" }'
                    }
                  }
              }
            }
        }], 'experimentRules' => []
      },
      'multi_variate_feature' => {
        'deliveryRules' => [], 'experimentRules' => [{
          'audiences' => '', 'id' => '122230', 'key' =>
            'test_experiment_multivariate', 'variationsMap' => {
              'Feorge' => {
                'featureEnabled' => false, 'id' => '122232', 'key' =>
                  'Feorge', 'variablesMap' => {
                    'first_letter' => {
                      'id' => '155560', 'key' => 'first_letter', 'type' =>
                        'string', 'value' => 'H'
                    }, 'rest_of_name' => {
                      'id' => '155561', 'key' => 'rest_of_name', 'type' =>
                      'string', 'value' => 'arry'
                    }
                  }
              }, 'Fred' => {
                'featureEnabled' => true, 'id' => '122231', 'key' =>
                'Fred', 'variablesMap' => {
                  'first_letter' => {
                    'id' => '155560', 'key' => 'first_letter', 'type' =>
                      'string', 'value' => 'F'
                  }, 'rest_of_name' => {
                    'id' => '155561', 'key' => 'rest_of_name', 'type' =>
                    'string', 'value' => 'red'
                  }
                }
              }, 'George' => {
                'featureEnabled' => true, 'id' => '122234', 'key' =>
                'George', 'variablesMap' => {
                  'first_letter' => {
                    'id' => '155560', 'key' => 'first_letter', 'type' =>
                      'string', 'value' => 'G'
                  }, 'rest_of_name' => {
                    'id' => '155561', 'key' => 'rest_of_name', 'type' =>
                    'string', 'value' => 'eorge'
                  }
                }
              }, 'Gred' => {
                'featureEnabled' => true, 'id' => '122233', 'key' =>
                'Gred', 'variablesMap' => {
                  'first_letter' => {
                    'id' => '155560', 'key' => 'first_letter', 'type' =>
                      'string', 'value' => 'G'
                  }, 'rest_of_name' => {
                    'id' => '155561', 'key' => 'rest_of_name', 'type' =>
                    'string', 'value' => 'red'
                  }
                }
              }
            }
        }]
      },
      'mutex_group_feature' => {
        'deliveryRules' => [], 'experimentRules' => [{
          'audiences' => '', 'id' => '133331', 'key' => 'group1_exp1',
          'variationsMap' => {
            'g1_e1_v1' => {
              'featureEnabled' => true, 'id' => '130001', 'key' =>
                'g1_e1_v1', 'variablesMap' => {
                  'correlating_variation_name' => {
                    'id' => '155563', 'key' =>
                      'correlating_variation_name', 'type' => 'string',
                    'value' => 'groupie_1_v1'
                  }
                }
            }, 'g1_e1_v2' => {
              'featureEnabled' => true, 'id' => '130002', 'key' =>
                                                             'g1_e1_v2', 'variablesMap' => {
                                                               'correlating_variation_name' => {
                                                                 'id' => '155563', 'key' =>
                                                                   'correlating_variation_name', 'type' => 'string',
                                                                 'value' => 'groupie_1_v2'
                                                               }
                                                             }
            }
          }
        }, {
          'audiences' => '', 'id' => '133332', 'key' => 'group1_exp2',
          'variationsMap' => {
            'g1_e2_v1' => {
              'featureEnabled' => true, 'id' => '130003', 'key' =>
                'g1_e2_v1', 'variablesMap' => {
                  'correlating_variation_name' => {
                    'id' => '155563', 'key' =>
                      'correlating_variation_name', 'type' => 'string',
                    'value' => 'groupie_2_v1'
                  }
                }
            }, 'g1_e2_v2' => {
              'featureEnabled' => true, 'id' => '130004', 'key' =>
                                                             'g1_e2_v2', 'variablesMap' => {
                                                               'correlating_variation_name' => {
                                                                 'id' => '155563', 'key' =>
                                                                   'correlating_variation_name', 'type' => 'string',
                                                                 'value' => 'groupie_2_v2'
                                                               }
                                                             }
            }
          }
        }]
      },
      'string_single_variable_feature' => {
        'deliveryRules' => [{
          'audiences' => '', 'id' => '177774', 'key' => '177774',
          'variationsMap' => {
            '177775' => {
              'featureEnabled' => true, 'id' => '177775', 'key' =>
                '177775', 'variablesMap' => {
                  'string_variable' => {
                    'id' => '155558', 'key' => 'string_variable',
                    'type' => 'string', 'value' => 'wingardium leviosa'
                  }
                }
            }
          }
        }, {
          'audiences' => '', 'id' => '177779', 'key' => '177779',
          'variationsMap' => {
            '177780' => {
              'featureEnabled' => true, 'id' => '177780', 'key' =>
                '177780', 'variablesMap' => {
                  'string_variable' => {
                    'id' => '155558', 'key' => 'string_variable',
                    'type' => 'string', 'value' => 'wingardium leviosa'
                  }
                }
            }
          }
        }, {
          'audiences' => '', 'id' => '177780', 'key' =>
            'rollout_exp_with_diff_id_and_key', 'variationsMap' => {
              'rollout_var_with_diff_id_and_key' => {
                'featureEnabled' => true, 'id' => '177781', 'key' =>
                  'rollout_var_with_diff_id_and_key', 'variablesMap' => {
                    'string_variable' => {
                      'id' => '155558', 'key' => 'string_variable',
                      'type' => 'string', 'value' => 'wingardium leviosa'
                    }
                  }
              }
            }
        }], 'experimentRules' => [{
          'audiences' => '', 'id' => '122235', 'key' =>
            'test_experiment_with_feature_rollout', 'variationsMap' => {
              'control' => {
                'featureEnabled' => true, 'id' => '122236', 'key' =>
                  'control', 'variablesMap' => {
                    'string_variable' => {
                      'id' => '155558', 'key' => 'string_variable',
                      'type' => 'string', 'value' => 'cta_1'
                    }
                  }
              }, 'variation' => {
                'featureEnabled' => true, 'id' => '122237', 'key' =>
                'variation', 'variablesMap' => {
                  'string_variable' => {
                    'id' => '155558', 'key' => 'string_variable',
                    'type' => 'string', 'value' => 'cta_2'
                  }
                }
              }
            }
        }]
      }
    }
    project_config.feature_flags.each do |feature_flag|
      expect(features_map[feature_flag['key']]).to include(
        'id' => feature_flag['id'],
        'key' => feature_flag['key'],
        'deliveryRules' => expected_features_map[feature_flag['key']]['deliveryRules'],
        'experimentRules' => expected_features_map[feature_flag['key']]['experimentRules']
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

  it 'should serialize audiences and replace ids with names' do
    audience_conditions =
      [
        %w[or 3468206642 3988293898],
        %w[or 3468206642 3988293898 3468206646],
        %w[not 3468206642],
        %w[or 3468206642],
        %w[and 3468206642],
        ['3468206642'],
        %w[3468206642 3988293898],
        ['and', %w[or 3468206642 3988293898], '3468206646'],
        ['and', ['or', '3468206642', %w[and 3988293898 3468206646]], ['and', '3988293899', %w[or 3468206647 3468206643]]],
        %w[and and],
        ['not', %w[and 3468206642 3988293898]],
        [],
        %w[or 3468206642 999999999]
      ]

    expected_audience_outputs = [
      '"exactString" OR "substringString"',
      '"exactString" OR "substringString" OR "exactNumber"',
      'NOT "exactString"',
      '"exactString"',
      '"exactString"',
      '"exactString"',
      '"exactString" OR "substringString"',
      '("exactString" OR "substringString") AND "exactNumber"',
      '("exactString" OR ("substringString" AND "exactNumber")) AND ("exists" AND ("gtNumber" OR "exactBoolean"))',
      '',
      'NOT ("exactString" AND "substringString")',
      '',
      '"exactString" OR "999999999"'
    ]
    optimizely_config = Optimizely::OptimizelyConfig.new(project_instance_typed_audiences.send(:project_config))
    audiences_map = optimizely_config.send(:audiences_map)
    audience_conditions.each_with_index do |audience_condition, index|
      result = optimizely_config.send(:replace_ids_with_names, audience_condition, audiences_map)
      expect(result).to eq(expected_audience_outputs[index])
    end
  end

  it 'should return correct config revision' do
    expect(project_config.revision).to eq(optimizely_config['revision'])
  end

  it 'should return correct sdk key' do
    expect(project_config.sdk_key).to eq(optimizely_config['sdkKey'])
  end

  it 'should return correct environment key' do
    expect(project_config.environment_key).to eq(optimizely_config['environmentKey'])
  end

  it 'should return correct datafile string' do
    expect(project_config.datafile).to eq(optimizely_config['datafile'])
  end

  it 'should return default sdk key and environment key' do
    expect(optimizely_config_similar_rule_keys['sdkKey']).to eq('')
    expect(optimizely_config_similar_rule_keys['environmentKey']).to eq('')
  end
end
