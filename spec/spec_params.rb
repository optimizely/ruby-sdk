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
  V2_CONFIG_BODY = {
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
          'id' => '130001'
        }, {
          'key' => 'g1_e1_v2',
          'id' => '130002'
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
          'id' => '130003'
        }, {
          'key' => 'g1_e2_v2',
          'id' => '130004'
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
    }]
  }

  V1_CONFIG_BODY = {
    'accountId' => '12001',
    'projectId' => '111001',
    'revision' => '42',
    'version' => '1',
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
      'audienceIds' => ['11154'],
      'trafficAllocation' => [{
        'entityId' => '122228',
        'endOfRange' => 5000
      }, {
        'entityId' => '122229',
        'endOfRange' => 10000
      }],
      'forcedVariations' => {},
      'id' => '122227',
      'percentageIncluded' => 10000,
      'variations' => [{
        'key' => 'control_with_audience',
        'id' => '122228'
      }, {
        'key' => 'variation_with_audience',
        'id' => '122229'
      }]
    }],
    'dimensions' => [{
      'key' => 'browser_type',
      'id' => '111094',
      'segmentId' => '5175100584230912'
    }],
    'audiences' => [{
      'name' => 'Firefox users',
      'conditions' => '["and", ["or", ["or", '\
                      '{"name": "browser_type", "type": "custom_dimension", "value": "firefox"}]]]',
      'id' => '11154'
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
          'id' => '130001'
        }, {
          'key' => 'g1_e1_v2',
          'id' => '130002'
        }]
      }, {
        'id' => '133332',
        'key' => 'group1_exp2',
        'status' => 'Running',
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
          'id' => '130003'
        }, {
          'key' => 'g1_e2_v2',
          'id' => '130004'
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
    }]
  }

  V1_CONFIG_BODY_JSON = JSON.dump(V1_CONFIG_BODY)
  V2_CONFIG_BODY_JSON = JSON.dump(V2_CONFIG_BODY)
end
