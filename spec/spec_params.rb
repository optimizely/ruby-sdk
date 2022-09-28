# frozen_string_literal: true

#
#    Copyright 2016-2021, Optimizely and contributors
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

module OptimizelySpec
  VALID_CONFIG_BODY = {
    'accountId' => '12001',
    'projectId' => '111001',
    'anonymizeIP' => false,
    'botFiltering' => true,
    'revision' => '42',
    'sdkKey' => 'VALID',
    'environmentKey' => 'VALID_ENVIRONMENT',
    'version' => '2',
    'sendFlagDecisions' => true,
    'events' => [{
      'key' => 'test_event',
      'experimentIds' => %w[111127 122230],
      'id' => '111095'
    }, {
      'key' => 'Total Revenue',
      'experimentIds' => ['111127'],
      'id' => '111096'
    }, {
      'key' => 'test_event_with_audience',
      'experimentIds' => ['122227'],
      'id' => '111097'
    }, {
      'key' => 'test_event_not_running',
      'experimentIds' => ['100027'],
      'id' => '111098'
    }],
    'experiments' => [{
      'key' => 'test_experiment',
      'status' => 'Running',
      'layerId' => '1',
      'audienceIds' => [],
      'trafficAllocation' => [{
        'entityId' => '111128',
        'endOfRange' => 5000
      }, {
        'entityId' => '111129',
        'endOfRange' => 10_000
      }],
      'forcedVariations' => {
        'forced_user1' => 'control',
        'forced_user2' => 'variation',
        'forced_user_with_invalid_variation' => 'invalid_variation'
      },
      'id' => '111127',
      'percentageIncluded' => 10_000,
      'variations' => [{
        'key' => 'control',
        'id' => '111128',
        'featureEnabled' => true
      }, {
        'key' => 'variation',
        'id' => '111129',
        'featureEnabled' => true
      }]
    }, {
      'key' => 'test_experiment_not_started',
      'status' => 'Not started',
      'layerId' => '2',
      'audienceIds' => [],
      'trafficAllocation' => [{
        'entityId' => '100028',
        'endOfRange' => 5000
      }, {
        'entityId' => '100029',
        'endOfRange' => 10_000
      }],
      'forcedVariations' => {},
      'id' => '100027',
      'percentageIncluded' => 10_000,
      'variations' => [{
        'key' => 'control_not_started',
        'id' => '100028',
        'featureEnabled' => true
      }, {
        'key' => 'variation_not_started',
        'id' => '100029',
        'featureEnabled' => false
      }]
    }, {
      'key' => 'test_experiment_with_audience',
      'status' => 'Running',
      'layerId' => '3',
      'audienceIds' => ['11154'],
      'trafficAllocation' => [{
        'entityId' => '122228',
        'endOfRange' => 5000
      }, {
        'entityId' => '122229',
        'endOfRange' => 10_000
      }],
      'forcedVariations' => {
        'forced_audience_user' => 'variation_with_audience'
      },
      'id' => '122227',
      'percentageIncluded' => 10_000,
      'variations' => [{
        'key' => 'control_with_audience',
        'id' => '122228',
        'featureEnabled' => true
      }, {
        'key' => 'variation_with_audience',
        'id' => '122229',
        'featureEnabled' => true
      }]
    }, {
      'key' => 'test_experiment_multivariate',
      'status' => 'Running',
      'layerId' => '4',
      'audienceIds' => ['11154'],
      'id' => '122230',
      'forcedVariations' => {},
      'trafficAllocation' => [{
        'entityId' => '122231',
        'endOfRange' => 2500
      }, {
        'entityId' => '122232',
        'endOfRange' => 5000
      }, {
        'entityId' => '122233',
        'endOfRange' => 7500
      }, {
        'entityId' => '122234',
        'endOfRange' => 10_000
      }],
      'variations' => [{
        'id' => '122231',
        'key' => 'Fred',
        'featureEnabled' => true,
        'variables' => [
          {
            'id' => '155560',
            'value' => 'F'
          },
          {
            'id' => '155561',
            'value' => 'red'
          }
        ]
      }, {
        'id' => '122232',
        'key' => 'Feorge',
        'featureEnabled' => false,
        'variables' => [
          {
            'id' => '155560',
            'value' => 'F'
          },
          {
            'id' => '155561',
            'value' => 'eorge'
          }
        ]
      }, {
        'id' => '122233',
        'key' => 'Gred',
        'featureEnabled' => true,
        'variables' => [
          {
            'id' => '155560',
            'value' => 'G'
          },
          {
            'id' => '155561',
            'value' => 'red'
          }
        ]
      }, {
        'id' => '122234',
        'key' => 'George',
        'featureEnabled' => true,
        'variables' => [
          {
            'id' => '155560',
            'value' => 'G'
          },
          {
            'id' => '155561',
            'value' => 'eorge'
          }
        ]
      }]
    }, {
      'key' => 'test_experiment_with_feature_rollout',
      'status' => 'Running',
      'layerId' => '5',
      'audienceIds' => [],
      'id' => '122235',
      'forcedVariations' => {},
      'trafficAllocation' => [{
        'entityId' => '122236',
        'endOfRange' => 5000
      }, {
        'entityId' => '122237',
        'endOfRange' => 10_000
      }],
      'variations' => [{
        'id' => '122236',
        'key' => 'control',
        'featureEnabled' => true,
        'variables' => [{
          'id' => '155558',
          'value' => 'cta_1'
        }, {
          'id' => '1555588',
          'value' => '{"value": "cta_1"}'
        }]
      }, {
        'id' => '122237',
        'key' => 'variation',
        'featureEnabled' => true,
        'variables' => [{
          'id' => '155558',
          'value' => 'cta_2'
        }, {
          'id' => '1555588',
          'value' => '{"value": "cta_2"}'
        }]
      }]
    }, {
      'key' => 'test_experiment_double_feature',
      'status' => 'Running',
      'layerId' => '5',
      'audienceIds' => [],
      'id' => '122238',
      'forcedVariations' => {},
      'trafficAllocation' => [{
        'entityId' => '122239',
        'endOfRange' => 5000
      }, {
        'entityId' => '122240',
        'endOfRange' => 10_000
      }],
      'variations' => [{
        'id' => '122239',
        'key' => 'control',
        'featureEnabled' => true,
        'variables' => [
          {
            'id' => '155551',
            'value' => '42.42'
          }
        ]
      }, {
        'id' => '122240',
        'key' => 'variation',
        'featureEnabled' => true,
        'variables' => [
          {
            'id' => '155551',
            'value' => '13.37'
          }
        ]
      }]
    }, {
      'key' => 'test_experiment_integer_feature',
      'status' => 'Running',
      'layerId' => '6',
      'audienceIds' => [],
      'id' => '122241',
      'forcedVariations' => {},
      'trafficAllocation' => [{
        'entityId' => '122242',
        'endOfRange' => 5000
      }, {
        'entityId' => '122243',
        'endOfRange' => 10_000
      }],
      'variations' => [{
        'id' => '122242',
        'key' => 'control',
        'featureEnabled' => true,
        'variables' => [
          {
            'id' => '155553',
            'value' => '42'
          }
        ]
      }, {
        'id' => '122243',
        'key' => 'variation',
        'featureEnabled' => true,
        'variables' => [
          {
            'id' => '155553',
            'value' => '13'
          }
        ]
      }]
    }],
    'attributes' => [{
      'key' => 'browser_type',
      'id' => '111094'
    }, {
      'key' => 'boolean_key',
      'id' => '111095'
    }, {
      'key' => 'integer_key',
      'id' => '111096'
    }, {
      'key' => 'double_key',
      'id' => '111097'
    }],
    'audiences' => [{
      'name' => 'Firefox users',
      'conditions' => '["and", ["or", ["or", '\
                      '{"name": "browser_type", "type": "custom_attribute", "value": "firefox"}]]]',
      'id' => '11154'
    }, {
      'name' => 'Chrome users',
      'conditions' => '["and", ["or", ["or", '\
                      '{"name": "browser_type", "type": "custom_attribute", "value": "chrome"}]]]',
      'id' => '11155'
    }],
    'groups' => [{
      'id' => '101',
      'policy' => 'random',
      'trafficAllocation' => [{
        'entityId' => '133331',
        'endOfRange' => 4000
      }, {
        'entityId' => '133332',
        'endOfRange' => 10_000
      }],
      'experiments' => [{
        'id' => '133331',
        'key' => 'group1_exp1',
        'status' => 'Running',
        'layerId' => '4',
        'audienceIds' => [],
        'trafficAllocation' => [{
          'entityId' => '130001',
          'endOfRange' => 5000
        }, {
          'entityId' => '130002',
          'endOfRange' => 10_000
        }],
        'forcedVariations' => {},
        'percentageIncluded' => 10_000,
        'variations' => [{
          'key' => 'g1_e1_v1',
          'id' => '130001',
          'featureEnabled' => true,
          'variables' => [
            {
              'id' => '155563',
              'value' => 'groupie_1_v1'
            }
          ]
        }, {
          'key' => 'g1_e1_v2',
          'id' => '130002',
          'featureEnabled' => true,
          'variables' => [
            {
              'id' => '155563',
              'value' => 'groupie_1_v2'
            }
          ]
        }]
      }, {
        'id' => '133332',
        'key' => 'group1_exp2',
        'status' => 'Running',
        'layerId' => '5',
        'audienceIds' => [],
        'trafficAllocation' => [{
          'entityId' => '130003',
          'endOfRange' => 5000
        }, {
          'entityId' => '130004',
          'endOfRange' => 10_000
        }],
        'forcedVariations' => {
          'forced_group_user1' => 'g1_e2_v2'
        },
        'percentageIncluded' => 10_000,
        'variations' => [{
          'key' => 'g1_e2_v1',
          'id' => '130003',
          'featureEnabled' => true,
          'variables' => [
            {
              'id' => '155563',
              'value' => 'groupie_2_v1'
            }
          ]
        }, {
          'key' => 'g1_e2_v2',
          'id' => '130004',
          'featureEnabled' => true,
          'variables' => [
            {
              'id' => '155563',
              'value' => 'groupie_2_v2'
            }
          ]
        }]
      }]
    }, {
      'id' => '102',
      'policy' => 'overlapping',
      'trafficAllocation' => [],
      'experiments' => [{
        'id' => '144441',
        'key' => 'group2_exp1',
        'status' => 'Running',
        'layerId' => '6',
        'audienceIds' => [],
        'trafficAllocation' => [{
          'entityId' => '144443',
          'endOfRange' => 5000
        }, {
          'entityId' => '144444',
          'endOfRange' => 10_000
        }],
        'forcedVariations' => {},
        'percentageIncluded' => 10_000,
        'variations' => [{
          'key' => 'g2_e1_v1',
          'id' => '144443',
          'featureEnabled' => true
        }, {
          'key' => 'g2_e1_v2',
          'id' => '144444',
          'featureEnabled' => true
        }]
      }, {
        'id' => '144442',
        'key' => 'group2_exp2',
        'status' => 'Running',
        'layerId' => '7',
        'audienceIds' => [],
        'trafficAllocation' => [{
          'entityId' => '144445',
          'endOfRange' => 5000
        }, {
          'entityId' => '144446',
          'endOfRange' => 10_000
        }],
        'forcedVariations' => {},
        'percentageIncluded' => 10_000,
        'variations' => [{
          'key' => 'g2_e2_v1',
          'id' => '144445',
          'featureEnabled' => true
        }, {
          'key' => 'g2_e2_v2',
          'id' => '144446',
          'featureEnabled' => true
        }]
      }]
    }],
    'featureFlags' => [{
      'id' => '155549',
      'key' => 'boolean_feature',
      'rolloutId' => '',
      'experimentIds' => ['122227'],
      'variables' => []
    }, {
      'id' => '155550',
      'key' => 'double_single_variable_feature',
      'rolloutId' => '',
      'experimentIds' => ['122238'],
      'variables' => [
        {
          'id' => '155551',
          'key' => 'double_variable',
          'type' => 'double',
          'defaultValue' => '14.99'
        }
      ]
    }, {
      'id' => '155552',
      'key' => 'integer_single_variable_feature',
      'rolloutId' => '',
      'experimentIds' => ['122241'],
      'variables' => [
        {
          'id' => '155553',
          'key' => 'integer_variable',
          'type' => 'integer',
          'defaultValue' => '7'
        }
      ]
    }, {
      'id' => '155554',
      'key' => 'boolean_single_variable_feature',
      'rolloutId' => '166660',
      'experimentIds' => [],
      'variables' => [
        {
          'id' => '155556',
          'key' => 'boolean_variable',
          'type' => 'boolean',
          'defaultValue' => 'true'
        }
      ]
    }, {
      'id' => '155557',
      'key' => 'string_single_variable_feature',
      'rolloutId' => '166661',
      'experimentIds' => ['122235'],
      'variables' => [
        {
          'id' => '155558',
          'key' => 'string_variable',
          'type' => 'string',
          'defaultValue' => 'wingardium leviosa'
        }
      ]
    }, {
      'id' => '155559',
      'key' => 'multi_variate_feature',
      'rolloutId' => '',
      'experimentIds' => ['122230'],
      'variables' => [
        {
          'id' => '155560',
          'key' => 'first_letter',
          'type' => 'string',
          'defaultValue' => 'H'
        },
        {
          'id' => '155561',
          'key' => 'rest_of_name',
          'type' => 'string',
          'defaultValue' => 'arry'
        }
      ]
    }, {
      'id' => '155562',
      'key' => 'mutex_group_feature',
      'rolloutId' => '',
      'experimentIds' => %w[133331 133332],
      'variables' => [
        {
          'id' => '155563',
          'key' => 'correlating_variation_name',
          'type' => 'string',
          'defaultValue' => 'null'
        }
      ]
    }, {
      'id' => '155564',
      'key' => 'empty_feature',
      'rolloutId' => '',
      'experimentIds' => [],
      'variables' => []
    }, {
      'id' => '15555577',
      'key' => 'json_single_variable_feature',
      'rolloutId' => '166661',
      'experimentIds' => [],
      'variables' => [
        {
          'id' => '1555588',
          'key' => 'json_variable',
          'type' => 'string',
          'subType' => 'json',
          'defaultValue' => '{ "val": "wingardium leviosa" }'
        }
      ]
    }, {
      'id' => '155555777',
      'key' => 'all_variables_feature',
      'rolloutId' => '1666611',
      'experimentIds' => [],
      'variables' => [
        {
          'id' => '155558891',
          'key' => 'json_variable',
          'type' => 'string',
          'subType' => 'json',
          'defaultValue' => '{ "val": "default json" }'
        }, {
          'id' => '155558892',
          'key' => 'string_variable',
          'type' => 'string',
          'defaultValue' => 'default string'
        }, {
          'id' => '155558893',
          'key' => 'boolean_variable',
          'type' => 'boolean',
          'defaultValue' => 'false'
        }, {
          'id' => '155558894',
          'key' => 'double_variable',
          'type' => 'double',
          'defaultValue' => '1.99'
        }, {
          'id' => '155558895',
          'key' => 'integer_variable',
          'type' => 'integer',
          'defaultValue' => '10'
        }
      ]
    }],
    'rollouts' => [{
      'id' => '166660',
      'experiments' => [{
        'id' => '177770',
        'key' => '177770',
        'status' => 'Running',
        'layerId' => '166660',
        'audienceIds' => ['11154'],
        'variations' => [{
          'id' => '177771',
          'key' => '177771',
          'featureEnabled' => true,
          'variables' => [
            {
              'id' => '155556',
              'value' => 'true'
            }
          ]
        }],
        'trafficAllocation' => [{
          'entityId' => '177771',
          'endOfRange' => 1000
        }]
      }, {
        'id' => '177772',
        'key' => '177772',
        'status' => 'Running',
        'layerId' => '166660',
        'audienceIds' => ['11155'],
        'variations' => [{
          'id' => '177773',
          'key' => '177773',
          'featureEnabled' => false,
          'variables' => [
            {
              'id' => '155556',
              'value' => 'false'
            }
          ]
        }],
        'trafficAllocation' => [{
          'entityId' => '177773',
          'endOfRange' => 10_000
        }]
      }, {
        'id' => '177776',
        'key' => '177776',
        'status' => 'Running',
        'layerId' => '166660',
        'audienceIds' => [],
        'variations' => [{
          'id' => '177778',
          'key' => '177778',
          'featureEnabled' => true,
          'variables' => [
            {
              'id' => '155556',
              'value' => 'false'
            }
          ]
        }],
        'trafficAllocation' => [{
          'entityId' => '177778',
          'endOfRange' => 10_000
        }]
      }]
    }, {
      'id' => '166661',
      'experiments' => [{
        'id' => '177774',
        'key' => '177774',
        'status' => 'Running',
        'layerId' => '166661',
        'audienceIds' => ['11154'],
        'variations' => [{
          'id' => '177775',
          'key' => '177775',
          'featureEnabled' => true,
          'variables' => []
        }],
        'trafficAllocation' => [{
          'entityId' => '177775',
          'endOfRange' => 1500
        }]
      }, {
        'id' => '177779',
        'key' => '177779',
        'status' => 'Running',
        'layerId' => '166661',
        'audienceIds' => [],
        'variations' => [{
          'id' => '177780',
          'key' => '177780',
          'featureEnabled' => true,
          'variables' => []
        }],
        'trafficAllocation' => [{
          'entityId' => '177780',
          'endOfRange' => 1500
        }]
      }, {
        'id' => '177780',
        'key' => 'rollout_exp_with_diff_id_and_key',
        'status' => 'Running',
        'layerId' => '166661',
        'audienceIds' => [],
        'variations' => [{
          'id' => '177781',
          'key' => 'rollout_var_with_diff_id_and_key',
          'featureEnabled' => true,
          'variables' => []
        }],
        'trafficAllocation' => [{
          'entityId' => '177781',
          'endOfRange' => 1500
        }]
      }]
    }]
  }.freeze

  CONFIG_DICT_WITH_TYPED_AUDIENCES = {
    'version' => '4',
    'rollouts' => [
      {
        'experiments' => [
          {
            'status' => 'Running',
            'key' => '11488548027',
            'layerId' => '11551226731',
            'trafficAllocation' => [
              {
                'entityId' => '11557362669',
                'endOfRange' => 10_000
              }
            ],
            'audienceIds' => %w[3468206642 3988293898 3988293899 3468206646 3468206647 3468206644 3468206643],
            'variations' => [
              {
                'variables' => [],
                'id' => '11557362669',
                'key' => '11557362669',
                'featureEnabled' => true
              }
            ],
            'forcedVariations' => {},
            'id' => '11488548027'
          }
        ],
        'id' => '11551226731'
      },
      {
        'experiments' => [
          {
            'status' => 'Paused',
            'key' => '11630490911',
            'layerId' => '11638870867',
            'trafficAllocation' => [
              {
                'entityId' => '11475708558',
                'endOfRange' => 0
              }
            ],
            'audienceIds' => [],
            'variations' => [
              {
                'variables' => [],
                'id' => '11475708558',
                'key' => '11475708558',
                'featureEnabled' => false
              }
            ],
            'forcedVariations' => {},
            'id' => '11630490911'
          }
        ],
        'id' => '11638870867'
      },
      {
        'experiments' => [
          {
            'status' => 'Running',
            'key' => '11488548028',
            'layerId' => '11551226732',
            'trafficAllocation' => [
              {
                'entityId' => '11557362670',
                'endOfRange' => 10_000
              }
            ],
            'audienceIds' => ['0'],
            'audienceConditions' => ['and', %w[or 3468206642 3988293898], %w[or 3988293899 3468206646 3468206647 3468206644 3468206643]],
            'variations' => [
              {
                'variables' => [],
                'id' => '11557362670',
                'key' => '11557362670',
                'featureEnabled' => true
              }
            ],
            'forcedVariations' => {},
            'id' => '11488548028'
          }
        ],
        'id' => '11551226732'
      },
      {
        'experiments' => [
          {
            'status' => 'Paused',
            'key' => '11630490912',
            'layerId' => '11638870868',
            'trafficAllocation' => [
              {
                'entityId' => '11475708559',
                'endOfRange' => 0
              }
            ],
            'audienceIds' => [],
            'variations' => [
              {
                'variables' => [],
                'id' => '11475708559',
                'key' => '11475708559',
                'featureEnabled' => false
              }
            ],
            'forcedVariations' => {},
            'id' => '11630490912'
          }
        ],
        'id' => '11638870868'
      }

    ],
    'anonymizeIP' => false,
    'projectId' => '11624721371',
    'variables' => [],
    'featureFlags' => [
      {
        'experimentIds' => [],
        'rolloutId' => '11551226731',
        'variables' => [],
        'id' => '11477755619',
        'key' => 'feat'
      },
      {
        'experimentIds' => [
          '11564051718'
        ],
        'rolloutId' => '11638870867',
        'variables' => [
          {
            'defaultValue' => 'x',
            'type' => 'string',
            'id' => '11535264366',
            'key' => 'x'
          }
        ],
        'id' => '11567102051',
        'key' => 'feat_with_var'
      },
      {
        'experimentIds' => [],
        'rolloutId' => '11551226732',
        'variables' => [],
        'id' => '11567102052',
        'key' => 'feat2'
      },
      {
        'experimentIds' => ['1323241599'],
        'rolloutId' => '11638870868',
        'variables' => [
          {
            'defaultValue' => '10',
            'type' => 'integer',
            'id' => '11535264367',
            'key' => 'z'
          }
        ],
        'id' => '11567102053',
        'key' => 'feat2_with_var'
      }
    ],
    'experiments' => [
      {
        'status' => 'Running',
        'key' => 'feat_with_var_test',
        'layerId' => '11504144555',
        'trafficAllocation' => [
          {
            'entityId' => '11617170975',
            'endOfRange' => 10_000
          }
        ],
        'audienceIds' => %w[3468206642 3988293898 3988293899 3468206646 3468206647 3468206644 3468206643],
        'variations' => [
          {
            'variables' => [
              {
                'id' => '11535264366',
                'value' => 'xyz'
              }
            ],
            'id' => '11617170975',
            'key' => 'variation_2',
            'featureEnabled' => true
          }
        ],
        'forcedVariations' => {},
        'id' => '11564051718'
      },
      {
        'id' => '1323241597',
        'key' => 'typed_audience_experiment',
        'layerId' => '1630555627',
        'status' => 'Running',
        'variations' => [
          {
            'id' => '1423767503',
            'key' => 'A',
            'variables' => []
          }
        ],
        'trafficAllocation' => [
          {
            'entityId' => '1423767503',
            'endOfRange' => 10_000
          }
        ],
        'audienceIds' => %w[3468206642 3988293898 3988293899 3468206646 3468206647 3468206644 3468206643],
        'forcedVariations' => {}
      },
      {
        'id' => '1323241598',
        'key' => 'audience_combinations_experiment',
        'layerId' => '1323241598',
        'status' => 'Running',
        'variations' => [
          {
            'id' => '1423767504',
            'key' => 'A',
            'variables' => []
          }
        ],
        'trafficAllocation' => [
          {
            'entityId' => '1423767504',
            'endOfRange' => 10_000
          }
        ],
        'audienceIds' => ['0'],
        'audienceConditions' => ['and', %w[or 3468206642 3988293898], %w[or 3988293899 3468206646 3468206647 3468206644 3468206643]],
        'forcedVariations' => {}
      },
      {
        'id' => '1323241599',
        'key' => 'feat2_with_var_test',
        'layerId' => '1323241600',
        'status' => 'Running',
        'variations' => [
          {
            'variables' => [
              {
                'id' => '11535264367',
                'value' => '150'
              }
            ],
            'id' => '1423767505',
            'key' => 'variation_2',
            'featureEnabled' => true
          }
        ],
        'trafficAllocation' => [
          {
            'entityId' => '1423767505',
            'endOfRange' => 10_000
          }
        ],
        'audienceIds' => ['0'],
        'audienceConditions' => ['and', %w[or 3468206642 3988293898], %w[or 3988293899 3468206646 3468206647 3468206644 3468206643]],
        'forcedVariations' => {}
      }
    ],
    'audiences' => [
      {
        'id' => '3468206642',
        'name' => 'exactString',
        'conditions' => '["and", ["or", ["or", {"name": "house", "type": "custom_attribute", "value": "Gryffindor"}]]]'
      },
      {
        'id' => '3988293898',
        'name' => '$$dummySubstringString',
        'conditions' => '{ "type": "custom_attribute", "name": "$opt_dummy_attribute", "value": "impossible_value" }'
      },
      {
        'id' => '3988293899',
        'name' => '$$dummyExists',
        'conditions' => '{ "type": "custom_attribute", "name": "$opt_dummy_attribute", "value": "impossible_value" }'
      },
      {
        'id' => '3468206646',
        'name' => '$$dummyExactNumber',
        'conditions' => '{ "type": "custom_attribute", "name": "$opt_dummy_attribute", "value": "impossible_value" }'
      },
      {
        'id' => '3468206647',
        'name' => '$$dummyGtNumber',
        'conditions' => '{ "type": "custom_attribute", "name": "$opt_dummy_attribute", "value": "impossible_value" }'
      },
      {
        'id' => '3468206644',
        'name' => '$$dummyLtNumber',
        'conditions' => '{ "type": "custom_attribute", "name": "$opt_dummy_attribute", "value": "impossible_value" }'
      },
      {
        'id' => '3468206643',
        'name' => '$$dummyExactBoolean',
        'conditions' => '{ "type": "custom_attribute", "name": "$opt_dummy_attribute", "value": "impossible_value" }'
      },
      {
        'id' => '3468206645',
        'name' => '$$dummyMultipleCustomAttrs',
        'conditions' => '{ "type": "custom_attribute", "name": "$opt_dummy_attribute", "value": "impossible_value" }'
      },
      {
        'id' => '0',
        'name' => '$$dummy',
        'conditions' => '{ "type": "custom_attribute", "name": "$opt_dummy_attribute", "value": "impossible_value" }'
      }
    ],
    'typedAudiences' => [
      {
        'id' => '3988293898',
        'name' => 'substringString',
        'conditions' => ['and', ['or', ['or', {'name' => 'house', 'type' => 'custom_attribute',
                                               'match' => 'substring', 'value' => 'Slytherin'}]]]
      },
      {
        'id' => '3988293899',
        'name' => 'exists',
        'conditions' => ['and', ['or', ['or', {'name' => 'favorite_ice_cream', 'type' => 'custom_attribute',
                                               'match' => 'exists'}]]]
      },
      {
        'id' => '3468206646',
        'name' => 'exactNumber',
        'conditions' => ['and', ['or', ['or', {'name' => 'lasers', 'type' => 'custom_attribute',
                                               'match' => 'exact', 'value' => 45.5}]]]
      },
      {
        'id' => '3468206647',
        'name' => 'gtNumber',
        'conditions' => ['and', ['or', ['or', {'name' => 'lasers', 'type' => 'custom_attribute',
                                               'match' => 'gt', 'value' => 70}]]]
      },
      {
        'id' => '3468206644',
        'name' => 'ltNumber',
        'conditions' => ['and', ['or', ['or', {'name' => 'lasers', 'type' => 'custom_attribute',
                                               'match' => 'lt', 'value' => 1.0}]]]
      },
      {
        'id' => '3468206643',
        'name' => 'exactBoolean',
        'conditions' => ['and', ['or', ['or', {'name' => 'should_do_it', 'type' => 'custom_attribute',
                                               'match' => 'exact', 'value' => true}]]]
      },
      {
        'id' => '3468206645',
        'name' => 'multiple_custom_attrs',
        'conditions' => ['and', ['or', ['or', {'type' => 'custom_attribute', 'name' => 'browser', 'value' => 'chrome'},
                                        {'type' => 'custom_attribute', 'name' => 'browser', 'value' => 'firefox'}]]]
      }
    ],
    'groups' => [],
    'attributes' => [
      {
        'key' => 'house',
        'id' => '594015'
      },
      {
        'key' => 'lasers',
        'id' => '594016'
      },
      {
        'key' => 'should_do_it',
        'id' => '594017'
      },
      {
        'key' => 'favorite_ice_cream',
        'id' => '594018'
      }
    ],
    'botFiltering' => false,
    'accountId' => '4879520872',
    'events' => [
      {
        'key' => 'item_bought',
        'id' => '594089',
        'experimentIds' => %w[
          11564051718
          1323241597
        ]
      },
      {
        'key' => 'user_signed_up',
        'id' => '594090',
        'experimentIds' => %w[1323241598 1323241599]
      }
    ],
    'revision' => '3',
    'sdkKey' => 'AUDIENCES',
    'environmentKey' => 'AUDIENCES_ENVIRONMENT',
    'sendFlagDecisions' => true
  }.freeze

  CONFIG_DICT_WITH_INTEGRATIONS = {
    'version' => '4',
    'sendFlagDecisions' => true,
    'rollouts' => [
      {
        'experiments' => [
          {
            'audienceIds' => ['13389130056'],
            'forcedVariations' => {},
            'id' => '3332020515',
            'key' => 'rollout-rule-1',
            'layerId' => '3319450668',
            'status' => 'Running',
            'trafficAllocation' => [
              {
                'endOfRange' => 10_000,
                'entityId' => '3324490633'
              }
            ],
            'variations' => [
              {
                'featureEnabled' => true,
                'id' => '3324490633',
                'key' => 'rollout-variation-on',
                'variables' => []
              }
            ]
          },
          {
            'audienceIds' => [],
            'forcedVariations' => {},
            'id' => '3332020556',
            'key' => 'rollout-rule-2',
            'layerId' => '3319450668',
            'status' => 'Running',
            'trafficAllocation' => [
              {
                'endOfRange' => 10_000,
                'entityId' => '3324490644'
              }
            ],
            'variations' => [
              {
                'featureEnabled' => false,
                'id' => '3324490644',
                'key' => 'rollout-variation-off',
                'variables' => []
              }
            ]
          }
        ],
        'id' => '3319450668'
      }
    ],
    'anonymizeIP' => true,
    'botFiltering' => true,
    'projectId': '10431130345',
    'variables': [],
    'featureFlags': [
      {
        'experimentIds' => ['10390977673'],
        'id' => '4482920077',
        'key' => 'flag-segment',
        'rolloutId' => '3319450668',
        'variables' => [
          {
            'defaultValue' => '42',
            'id' => '2687470095',
            'key' => 'i_42',
            'type' => 'integer'
          }
        ]
      }
    ],
    'experiments' => [
      {
        'status' => 'Running',
        'key' => 'experiment-segment',
        'layerId' => '10420273888',
        'trafficAllocation' => [
          {
            'entityId' => '10389729780',
            'endOfRange' => 10_000
          }
        ],
        'audienceIds' => ['$opt_dummy_audience'],
        'audienceConditions' => %w[or 13389142234 13389141123],
        'variations' => [
          {
            'variables' => [],
            'featureEnabled' => true,
            'id' => '10389729780',
            'key' => 'variation-a'
          },
          {
            'variables' => [],
            'id' => '10416523121',
            'key' => 'variation-b'
          }
        ],
        'forcedVariations' => {},
        'id' => '10390977673'
      }
    ],
    'groups' => [],
    'integrations' => [
      {
        'key' => 'odp',
        'host' => 'https://api.zaius.com',
        'publicKey' => 'W4WzcEs-ABgXorzY7h1LCQ'
      }
    ],
    'typedAudiences' => [
      {
        'id' => '13389142234',
        'conditions' => [
          'and',
          [
            'or',
            [
              'or',
              {
                'value' => 'odp-segment-1',
                'type' => 'third_party_dimension',
                'name' => 'odp.audiences',
                'match' => 'qualified'
              }
            ]
          ]
        ],
        'name' => 'odp-segment-1'
      },
      {
        'id' => '13389130056',
        'conditions' => [
          'and',
          [
            'or',
            [
              'or',
              {
                'value' => 'odp-segment-2',
                'type' => 'third_party_dimension',
                'name' => 'odp.audiences',
                'match' => 'qualified'
              },
              {
                'value' => 'us',
                'type' => 'custom_attribute',
                'name' => 'country',
                'match' => 'exact'
              }
            ],
            [
              'or',
              {
                'value' => 'odp-segment-3',
                'type' => 'third_party_dimension',
                'name' => 'odp.audiences',
                'match' => 'qualified'
              }
            ]
          ]
        ],
        'name' => 'odp-segment-2'
      }
    ],
    'audiences' => [
      {
        'id' => '13389141123',
        'conditions' => '["and", ["or", ["or", {"match": "gt", "name": "age", "type": "custom_attribute", "value": 20}]]]',
        'name' => 'adult'
      }
    ],
    'attributes' => [
      {
        'id' => '10401066117',
        'key' => 'gender'
      },
      {
        'id' => '10401066170',
        'key' => 'testvar'
      },
      {
        'id' => '10401066171',
        'key' => 'age'
      }
    ],
    'accountId' => '10367498574',
    'events' => [],
    'revision' => '101'
  }.freeze

  SIMILAR_EXP_KEYS = {
    'version' => '4',
    'rollouts' => [],
    'sdkKey' => 'SIMILAR_KEYS',
    'environmentKey' => 'SIMILAR_KEYS_ENVIRONMENT',
    'typedAudiences' => [
      {
        'id' => '20415611520',
        'conditions' => ['and', ['or', ['or',
                                        {
                                          'value' => true,
                                          'type' => 'custom_attribute',
                                          'name' => 'hiddenLiveEnabled',
                                          'match' => 'exact'
                                        }]]],
        'name' => 'test1'
      },
      {
        'id' => '20406066925',
        'conditions' => ['and', ['or', ['or',
                                        {
                                          'value' => false,
                                          'type' => 'custom_attribute',
                                          'name' => 'hiddenLiveEnabled',
                                          'match' => 'exact'
                                        }]]],
        'name' => 'test2'
      }
    ], 'anonymizeIP' => true, 'projectId' => '20430981610',
    'variables' => [], 'featureFlags' => [
      {
        'experimentIds' => ['9300000007569'],
        'rolloutId' => '',
        'variables' => [],
        'id' => '3045',
        'key' => 'flag1'
      },
      {
        'experimentIds' => ['9300000007573'],
        'rolloutId' => '',
        'variables' => [],
        'id' => '3046',
        'key' => 'flag2'
      }
    ], 'experiments' => [
      {
        'status' => 'Running',
        'audienceConditions' => %w[or 20415611520],
        'audienceIds' => ['20415611520'],
        'variations' => [
          {
            'variables' => [],
            'id' => '8045',
            'key' => 'variation1',
            'featureEnabled' => true
          }
        ],
        'forcedVariations' =>
          {},
        'key' => 'targeted_delivery',
        'layerId' => '9300000007569',
        'trafficAllocation' => [
          {
            'entityId' => '8045',
            'endOfRange' => 10_000
          }
        ],
        'id' => '9300000007569'
      },
      {
        'status' => 'Running',
        'audienceConditions' => %w[or 20406066925],
        'audienceIds' => ['20406066925'],
        'variations' => [
          {
            'variables' => [],
            'id' => '8048',
            'key' => 'variation2',
            'featureEnabled' => true
          }
        ],
        'forcedVariations' =>
          {},
        'key' => 'targeted_delivery',
        'layerId' => '9300000007573',
        'trafficAllocation' => [
          {
            'entityId' => '8048',
            'endOfRange' => 10_000
          }
        ],
        'id' => '9300000007573'
      }
    ], 'audiences' => [
      {
        'id' => '20415611520',
        'conditions' =>
          '["or", {"match": "exact", "name": "$opt_dummy_attribute", "type": "custom_attribute", "value": "$opt_dummy_value"}]',
        'name' => 'test1'
      },
      {
        'id' => '20406066925',
        'conditions' =>
          '["or", {"match": "exact", "name": "$opt_dummy_attribute", "type": "custom_attribute", "value": "$opt_dummy_value"}]',
        'name' => 'test2'
      },
      {
        'conditions' =>
          '["or", {"match": "exact", "name": "$opt_dummy_attribute", "type": "custom_attribute", "value": "$opt_dummy_value"}]',
        'id' => '$opt_dummy_audience',
        'name' =>
          'Optimizely-Generated Audience for Backwards Compatibility'
      }
    ], 'groups' => [], 'attributes' => [
      {
        'id' => '20408641883',
        'key' => 'hiddenLiveEnabled'
      }
    ], 'botFiltering' => false, 'accountId' => '17882702980', 'events' => [],
    'revision' => '25', 'sendFlagDecisions' => true
  }.freeze

  SIMILAR_RULE_KEYS = {
    'version' => '4',
    'rollouts' => [
      {
        'experiments' => [
          {
            'status' => 'Running',
            'audienceConditions' => [],
            'audienceIds' => [],
            'variations' => [{
              'variables' => [],
              'id' => '5452',
              'key' => 'on',
              'featureEnabled' => true
            }],
            'forcedVariations' => {},
            'key' => 'targeted_delivery',
            'layerId' => '9300000004981',
            'trafficAllocation' => [{
              'entityId' => '5452', 'endOfRange' => 10_000
            }],
            'id' => '9300000004981'
          },
          {
            'status' => 'Running',
            'audienceConditions' => [],
            'audienceIds' => [],
            'variations' => [{
              'variables' => [],
              'id' => '5451',
              'key' => 'off',
              'featureEnabled' => false
            }],
            'forcedVariations' => {},
            'key' => 'default-rollout-2029-20301771717',
            'layerId' => 'default-layer-rollout-2029-20301771717',
            'trafficAllocation' => [{
              'entityId' => '5451', 'endOfRange' => 10_000
            }],
            'id' => 'default-rollout-2029-20301771717'
          }
        ],
        'id' => 'rollout-2029-20301771717'
      },
      {
        'experiments' => [
          {
            'status' => 'Running',
            'audienceConditions' => [],
            'audienceIds' => [],
            'variations' => [
              {
                'variables' => [],
                'id' => '5450',
                'key' => 'on',
                'featureEnabled' => true
              }
            ],
            'forcedVariations' => {},
            'key' => 'targeted_delivery',
            'layerId' => '9300000004979',
            'trafficAllocation' => [
              {
                'entityId' => '5450',
                'endOfRange' => 10_000
              }
            ],
            'id' => '9300000004979'
          },
          {
            'status' => 'Running',
            'audienceConditions' => [],
            'audienceIds' => [],
            'variations' => [
              {
                'variables' => [],
                'id' => '5449',
                'key' => 'off',
                'featureEnabled' => false
              }
            ],
            'forcedVariations' => {},
            'key' => 'default-rollout-2028-20301771717',
            'layerId' => 'default-layer-rollout-2028-20301771717',
            'trafficAllocation' => [
              {
                'entityId' => '5449',
                'endOfRange' => 10_000
              }
            ],
            'id' => 'default-rollout-2028-20301771717'
          }
        ],
        'id' => 'rollout-2028-20301771717'
      },
      {
        'experiments' => [
          {
            'status' => 'Running',
            'audienceConditions' => [],
            'audienceIds' => [],
            'variations' => [
              {
                'variables' => [],
                'id' => '5448',
                'key' => 'on',
                'featureEnabled' => true
              }
            ],
            'forcedVariations' => {},
            'key' => 'targeted_delivery',
            'layerId' => '9300000004977',
            'trafficAllocation' => [
              {
                'entityId' => '5448',
                'endOfRange' => 10_000
              }
            ], 'id' => '9300000004977'
          },
          {
            'status' => 'Running',
            'audienceConditions' => [],
            'audienceIds' => [],
            'variations' => [
              {
                'variables' => [],
                'id' => '5447',
                'key' => 'off',
                'featureEnabled' => false
              }
            ],
            'forcedVariations' => {},
            'key' => 'default-rollout-2027-20301771717',
            'layerId' => 'default-layer-rollout-2027-20301771717',
            'trafficAllocation' => [
              {
                'entityId' => '5447', 'endOfRange' => 10_000
              }
            ],
            'id' => 'default-rollout-2027-20301771717'
          }
        ],
        'id' => 'rollout-2027-20301771717'
      }
    ],
    'typedAudiences' => [],
    'anonymizeIP' => true,
    'projectId' => '20286295225',
    'variables' => [],
    'featureFlags' => [
      {
        'experimentIds' => [],
        'rolloutId' =>
        'rollout-2029-20301771717',
        'variables' => [],
        'id' => '2029',
        'key' => 'flag_3'
      },
      {
        'experimentIds' => [],
        'rolloutId' => 'rollout-2028-20301771717',
        'variables' => [],
        'id' => '2028',
        'key' => 'flag_2'
      },
      {
        'experimentIds' => [],
        'rolloutId' => 'rollout-2027-20301771717',
        'variables' => [],
        'id' => '2027',
        'key' => 'flag_1'
      }
    ],
    'experiments' => [],
    'audiences' => [
      {
        'conditions' =>
        '["or", {"match": "exact", "name": "$opt_dummy_attribute", "type": "custom_attribute", "value": "$opt_dummy_value"}]',
        'id' => '$opt_dummy_audience', 'name' =>
        'Optimizely-Generated Audience for Backwards Compatibility'
      }
    ],
    'groups' => [],
    'attributes' => [],
    'botFiltering' => false,
    'accountId' => '19947277778',
    'events' => [],
    'revision' => '11',
    'sendFlagDecisions' => true
  }.freeze

  DECIDE_FORCED_DECISION = {
    'version' => '4', 'sendFlagDecisions' => true, 'rollouts' => [{
      'experiments' => [{
        'audienceIds' => ['13389130056'],
        'forcedVariations' => {},
        'id' => '3332020515',
        'key' => '3332020515',
        'layerId' => '3319450668',
        'status' => 'Running',
        'trafficAllocation' => [{
          'endOfRange' => 9_000,
          'entityId' => '3324490633'
        }, {
          'entityId' => '3324490634',
          'endOfRange' => 1_000
        }],
        'variations' => [{
          'featureEnabled' => true,
          'id' => '3324490633',
          'key' => '3324490633',
          'variables' => []
        }, {
          'featureEnabled' => true,
          'id' => '3324490634',
          'key' => '3324490634',
          'variables' => []
        }]
      }, {
        'audienceIds' => ['12208130097'],
        'forcedVariations' => {},
        'id' => '3332020494',
        'key' => '3332020494',
        'layerId' => '3319450668',
        'status' => 'Running',
        'trafficAllocation' => [{
          'endOfRange' => 0,
          'entityId' => '3324490562'
        }, {
          'entityId' => '3324490634',
          'endOfRange' => 0
        }],
        'variations' => [{
          'featureEnabled' => true,
          'id' => '3324490562',
          'key' => '3324490562',
          'variables' => []
        }, {
          'featureEnabled' => true,
          'id' => '3324490634',
          'key' => '3324490634',
          'variables' => []
        }]
      }, {
        'status' => 'Running',
        'audienceIds' => [],
        'variations' => [{
          'variables' => [],
          'id' => '18257766532',
          'key' => '18257766532',
          'featureEnabled' => true
        }, {
          'featureEnabled' => true,
          'id' => '3324490634',
          'key' => '3324490634',
          'variables' => []
        }],
        'id' => '18322080788',
        'key' => '18322080788',
        'layerId' => '18263344648',
        'trafficAllocation' => [{
          'entityId' => '18257766532',
          'endOfRange' => 9_000
        }, {
          'entityId' => '3324490634',
          'endOfRange' => 1_000
        }],
        'forcedVariations' => {}
      }],
      'id' => '3319450668'
    }], 'anonymizeIP' => true, 'botFiltering' => true, 'projectId' => '10431130345', 'variables' => [], 'featureFlags' => [{
      'experimentIds' => ['10390977673'],
      'id' => '4482920077',
      'key' => 'feature_1',
      'rolloutId' => '3319450668',
      'variables' => [{
        'defaultValue' => '42',
        'id' => '2687470095',
        'key' => 'i_42',
        'type' => 'integer'
      }, {
        'defaultValue' => '4.2',
        'id' => '2689280165',
        'key' => 'd_4_2',
        'type' => 'double'
      }, {
        'defaultValue' => 'true',
        'id' => '2689660112',
        'key' => 'b_true',
        'type' => 'boolean'
      }, {
        'defaultValue' => 'foo',
        'id' => '2696150066',
        'key' => 's_foo',
        'type' => 'string'
      }, {
        'defaultValue' => '{"value":1}',
        'id' => '2696150067',
        'key' => 'j_1',
        'type' => 'string',
        'subType' => 'json'
      }, {
        'defaultValue' => 'invalid',
        'id' => '2696150068',
        'key' => 'i_1',
        'type' => 'invalid',
        'subType' => ''
      }]
    }, {
      'experimentIds' => ['10420810910'],
      'id' => '4482920078',
      'key' => 'feature_2',
      'rolloutId' => '',
      'variables' => [{
        'defaultValue' => '42',
        'id' => '2687470095',
        'key' => 'i_42',
        'type' => 'integer'
      }]
    }, {
      'experimentIds' => [],
      'id' => '44829230000',
      'key' => 'feature_3',
      'rolloutId' => '',
      'variables' => []
    }], 'experiments' => [{
      'status' => 'Running',
      'key' => 'exp_with_audience',
      'layerId' => '10420273888',
      'trafficAllocation' => [{
        'entityId' => '10389729780',
        'endOfRange' => 10_000
      }],
      'audienceIds' => ['13389141123'],
      'variations' => [{
        'variables' => [],
        'featureEnabled' => true,
        'id' => '10389729780',
        'key' => 'a'
      }, {
        'variables' => [],
        'id' => '10416523121',
        'key' => 'b'
      }],
      'forcedVariations' => {},
      'id' => '10390977673'
    }, {
      'status' => 'Running',
      'key' => 'exp_no_audience',
      'layerId' => '10417730432',
      'trafficAllocation' => [{
        'entityId' => '10418551353',
        'endOfRange' => 10_000
      }],
      'audienceIds' => [],
      'variations' => [{
        'variables' => [],
        'featureEnabled' => true,
        'id' => '10418551353',
        'key' => 'variation_with_traffic'
      }, {
        'variables' => [],
        'featureEnabled' => false,
        'id' => '10418510624',
        'key' => 'variation_no_traffic'
      }],
      'forcedVariations' => {},
      'id' => '10420810910'
    }], 'audiences' => [{
      'id' => '13389141123',
      'conditions' => '["and", ["or", ["or", {"match": "exact", "name": "gender", "type": "custom_attribute", "value": "f"}]]]',
      'name' => 'gender'
    }, {
      'id' => '13389130056',
      'conditions' => '["and", ["or", ["or", {"match": "exact", "name": "country", "type": "custom_attribute", "value": "US"}]]]',
      'name' => 'US'
    }, {
      'id' => '12208130097',
      'conditions' => '["and", ["or", ["or", {"match": "exact", "name": "browser", "type": "custom_attribute", "value": "safari"}]]]',
      'name' => 'safari'
    }, {
      'id' => 'age_18',
      'conditions' => '["and", ["or", ["or", {"match": "gt", "name": "age", "type": "custom_attribute", "value": 18}]]]',
      'name' => 'age_18'
    }, {
      'id' => 'invalid_format',
      'conditions' => '[]',
      'name' => 'invalid_format'
    }, {
      'id' => 'invalid_condition',
      'conditions' => '["and", ["or", ["or", {"match": "gt", "name": "age", "type": "custom_attribute", "value": "US"}]]]',
      'name' => 'invalid_condition'
    }, {
      'id' => 'invalid_type',
      'conditions' => '["and", ["or", ["or", {"match": "gt", "name": "age", "type": "invalid", "value": 18}]]]',
      'name' => 'invalid_type'
    }, {
      'id' => 'invalid_match',
      'conditions' => '["and", ["or", ["or", {"match": "invalid", "name": "age", "type": "custom_attribute", "value": 18}]]]',
      'name' => 'invalid_match'
    }, {
      'id' => 'nil_value',
      'conditions' => '["and", ["or", ["or", {"match": "gt", "name": "age", "type": "custom_attribute"}]]]',
      'name' => 'nil_value'
    }, {
      'id' => 'invalid_name',
      'conditions' => '["and", ["or", ["or", {"match": "gt", "type": "custom_attribute", "value": 18}]]]',
      'name' => 'invalid_name'
    }], 'groups' => [{
      'policy' => 'random',
      'trafficAllocation' => [{
        'entityId' => '10390965532',
        'endOfRange' => 10_000
      }],
      'experiments' => [{
        'status' => 'Running',
        'key' => 'group_exp_1',
        'layerId' => '10420222423',
        'trafficAllocation' => [{
          'entityId' => '10389752311',
          'endOfRange' => 10_000
        }],
        'audienceIds' => [],
        'variations' => [{
          'variables' => [],
          'featureEnabled' => false,
          'id' => '10389752311',
          'key' => 'a'
        }],
        'forcedVariations' => {},
        'id' => '10390965532'
      }, {
        'status' => 'Running',
        'key' => 'group_exp_2',
        'layerId' => '10417730432',
        'trafficAllocation' => [{
          'entityId' => '10418524243',
          'endOfRange' => 10_000
        }],
        'audienceIds' => [],
        'variations' => [{
          'variables' => [],
          'featureEnabled' => false,
          'id' => '10418524243',
          'key' => 'a'
        }],
        'forcedVariations' => {},
        'id' => '10420843432'
      }],
      'id' => '13142870430'
    }], 'attributes' => [{
      'id' => '10401066117',
      'key' => 'gender'
    }, {
      'id' => '10401066170',
      'key' => 'testvar'
    }], 'accountId' => '10367498574', 'events' => [{
      'experimentIds' => ['10420810910'],
      'id' => '10404198134',
      'key' => 'event1'
    }, {
      'experimentIds' => %w[10420810910 10390977673],
      'id' => '10404198135',
      'key' => 'event_multiple_running_exp_attached'
    }], 'revision' => '241'
  }.freeze

  VALID_CONFIG_BODY_JSON = JSON.dump(VALID_CONFIG_BODY)

  INVALID_CONFIG_BODY = VALID_CONFIG_BODY.dup
  INVALID_CONFIG_BODY['version'] = '5'
  INVALID_CONFIG_BODY_JSON = JSON.dump(INVALID_CONFIG_BODY)

  SIMILAR_EXP_KEYS_JSON = JSON.dump(SIMILAR_EXP_KEYS)

  CONFIG_DICT_WITH_TYPED_AUDIENCES_JSON = JSON.dump(CONFIG_DICT_WITH_TYPED_AUDIENCES)
  SIMILAR_RULE_KEYS_JSON = JSON.dump(SIMILAR_RULE_KEYS)

  DECIDE_FORCED_DECISION_JSON = JSON.dump(DECIDE_FORCED_DECISION)
  # SEND_FLAG_DECISIONS_DISABLED_CONFIG = VALID_CONFIG_BODY.dup
  # SEND_FLAG_DECISIONS_DISABLED_CONFIG['sendFlagDecisions'] = false

  CONFIG_DICT_WITH_INTEGRATIONS_JSON = JSON.dump(CONFIG_DICT_WITH_INTEGRATIONS)
end
