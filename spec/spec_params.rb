#
#    Copyright 2016-2017, Optimizely and contributors
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
    'revision' => '42',
    'version' => '2',
    'events' => [{
      'key' => 'test_event',
      'experimentIds' => ['111127'],
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
        'endOfRange' => 10000
      }],
      'forcedVariations' => {
        'forced_user1' => 'control',
        'forced_user2' => 'variation',
        'forced_user_with_invalid_variation' => 'invalid_variation'
      },
      'id' => '111127',
      'percentageIncluded' => 10000,
      'variations' => [{
        'key' => 'control',
        'id' => '111128'
      }, {
        'key' => 'variation',
        'id' => '111129'
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
        'endOfRange' => 10000
      }],
      'forcedVariations' => {},
      'id' => '100027',
      'percentageIncluded' => 10000,
      'variations' => [{
        'key' => 'control_not_started',
        'id' => '100028'
      }, {
        'key' => 'variation_not_started',
        'id' => '100029'
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
        'endOfRange' => 10000
      }],
      'forcedVariations' => {
        'forced_audience_user' => 'variation_with_audience',
      },
      'id' => '122227',
      'percentageIncluded' => 10000,
      'variations' => [{
        'key' => 'control_with_audience',
        'id' => '122228'
      }, {
        'key' => 'variation_with_audience',
        'id' => '122229'
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
        'endOfRange' => 10000
      }],
      'variations' => [{
        'id' => '122231',
        'key' => 'Fred',
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
      }],
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
        'endOfRange' => 10000
      }],
      'variations' => [{
        'id' => '122236',
        'key' => 'control',
        'variables' => [{
          'id' => '155558',
          'value' => 'cta_1'
        }]
      }, {
        'id' => '122237',
        'key' => 'variation',
        'variables' => [{
          'id' => '155558',
          'value' => 'cta_2'
        }]
      }]
    }],
    'attributes' => [{
      'key' => 'browser_type',
      'id' => '111094',
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
        'endOfRange' => 10000
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
          'endOfRange' => 10000
        }],
        'forcedVariations' => {},
        'percentageIncluded' => 10000,
        'variations' => [{
          'key' => 'g1_e1_v1',
          'id' => '130001',
          'variables' => [
            {
              'id' => '155563',
              'value' => 'groupie_1_v1'
            }
          ]
        }, {
          'key' => 'g1_e1_v2',
          'id' => '130002',
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
          'endOfRange' => 10000
        }],
        'forcedVariations' => {
          'forced_group_user1' => 'g1_e2_v2'
        },
        'percentageIncluded' => 10000,
        'variations' => [{
          'key' => 'g1_e2_v1',
          'id' => '130003',
          'variables' => [
            {
              'id' => '155563',
              'value' => 'groupie_2_v1'
            }
          ]
        }, {
          'key' => 'g1_e2_v2',
          'id' => '130004',
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
          'endOfRange' => 10000
        }],
        'forcedVariations' => {},
        'percentageIncluded' => 10000,
        'variations' => [{
          'key' => 'g2_e1_v1',
          'id' => '144443'
        }, {
          'key' => 'g2_e1_v2',
          'id' => '144444'
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
          'endOfRange' => 10000
        }],
        'forcedVariations' => {},
        'percentageIncluded' => 10000,
        'variations' => [{
          'key' => 'g2_e2_v1',
          'id' => '144445'
        }, {
          'key' => 'g2_e2_v2',
          'id' => '144446'
        }]
      }]
    }],
    'featureFlags' => [{
      'id' => '155549',
      'key' => 'boolean_feature',
      'rolloutId' => '',
      'experimentIds' => ['133331', '133332'],
      'variables' => []
    }, {
      'id'=> '155550',
      'key'=> 'double_single_variable_feature',
      'rolloutId'=> '',
      'experimentIds'=> [],
      'variables'=> [
        {
          'id'=> '155551',
          'key'=> 'double_variable',
          'type'=> 'double',
          'defaultValue'=> '14.99'
        }
      ]
    }, {
      'id'=> '155552',
      'key'=> 'integer_single_variable_feature',
      'rolloutId'=> '',
      'experimentIds'=> [],
      'variables'=> [
        {
          'id'=> '155553',
          'key'=> 'integer_variable',
          'type'=> 'integer',
          'defaultValue'=> '7'
        }
      ]
    }, {
      'id'=> '155554',
      'key'=> 'boolean_single_variable_feature',
      'rolloutId'=> '166660',
      'experimentIds'=> [],
      'variables'=> [
        {
          'id'=> '155556',
          'key'=> 'boolean_variable',
          'type'=> 'boolean',
          'defaultValue'=> 'true'
        }
      ]
    }, {
      'id'=> '155557',
      'key'=> 'string_single_variable_feature',
      'rolloutId'=> '166661',
      'experimentIds'=> ['122235'],
      'variables'=> [
        {
          'id'=> '155558',
          'key'=> 'string_variable',
          'type'=> 'string',
          'defaultValue'=> 'wingardium leviosa'
        }
      ]
    }, {
      'id'=> '155559',
      'key'=> 'multi_variate_feature',
      'rolloutId'=> '',
      'experimentIds'=> ['122230'],
      'variables'=> [
        {
          'id'=> '155560',
          'key'=> 'first_letter',
          'type'=> 'string',
          'defaultValue'=> 'H'
        },
        {
          'id'=> '155561',
          'key'=> 'rest_of_name',
          'type'=> 'string',
          'defaultValue'=> 'arry'
        }
      ]
    }, {
      'id'=> '155562',
      'key'=> 'mutex_group_feature',
      'rolloutId'=> '',
      'experimentIds'=> ['133331', '133332'],
      'variables'=> [
        {
          'id'=> '155563',
          'key'=> 'correlating_variation_name',
          'type'=> 'string',
          'defaultValue'=> 'null'
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
          'variables' => [
            {
              'id' => '155556',
              'value' => 'false'
            }
          ]
        }],
        'trafficAllocation' => [{
          'entityId' => '177773',
          'endOfRange' => 10000
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
          'variables' => [
            {
              'id' => '155556',
              'value' => 'false'
            }
          ]
        }],
        'trafficAllocation' => [{
          'entityId' => '177778',
          'endOfRange' => 10000
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
          'variables' => []
        }],
        'trafficAllocation' => [{
          'entityId' => '177780',
          'endOfRange' => 1500
        }]
      }]
    }]
  }

  VALID_CONFIG_BODY_JSON = JSON.dump(VALID_CONFIG_BODY)

  INVALID_CONFIG_BODY = VALID_CONFIG_BODY.dup
  INVALID_CONFIG_BODY['version'] = '1'
  INVALID_CONFIG_BODY_JSON = JSON.dump(INVALID_CONFIG_BODY)
end
