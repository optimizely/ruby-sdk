# frozen_string_literal: true

#
#    Copyright 2016-2019, Optimizely and contributors
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
    'version' => '2',
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
        }]
      }, {
        'id' => '122237',
        'key' => 'variation',
        'featureEnabled' => true,
        'variables' => [{
          'id' => '155558',
          'value' => 'cta_2'
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
      'experimentIds' => %w[133331 133332],
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
    'revision' => '3'
  }.freeze

  VALID_CONFIG_BODY_JSON = JSON.dump(VALID_CONFIG_BODY)

  INVALID_CONFIG_BODY = VALID_CONFIG_BODY.dup
  INVALID_CONFIG_BODY['version'] = '5'
  INVALID_CONFIG_BODY_JSON = JSON.dump(INVALID_CONFIG_BODY)
end
