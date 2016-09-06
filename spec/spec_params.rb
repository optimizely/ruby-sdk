require 'json'

module OptimizelySpec
  V2_CONFIG_BODY = {
    'revision' => '42',
    'version' => '2',
    'events' => [{
      'key' => 'testEvent',
      'experimentIds' => ['111127'],
      'id' => '111095'
    }, {
      'key' => 'testEventWithAudiences',
      'experimentIds' => ['122227'],
      'id' => '111097'
    }, {
      'key' => 'testEventWithoutExperiments',
      'experimentIds' => [],
      'id' => '111098'
    }, {
      'key' => 'testEventWithExperimentNotRunning',
      'experimentIds' => ['133337'],
      'id' => '111099'
    }, {
      'key' => 'testEventWithMultipleExperiments',
      'experimentIds' => ['111127', '122227', '133337'],
      'id' => '111100'
    }],
    'groups' => [{
      'id' => '666',
      'policy' => 'random',
      'trafficAllocation' => [{
        'entityId' => '442',
        'endOfRange' => 3000
      }, {
        'entityId' => '443',
        'endOfRange' => 6000
      }],
      'experiments' => [{
        'id' => '442',
        'key' => 'groupExperiment1',
        'status' => 'Running',
        'variations' => [{
          'id' => '551',
          'key' => 'var1exp1'
        }, {
          'id' => '552',
          'key' => 'var2exp1'
        }],
        'trafficAllocation' => [{
          'entityId' => '551',
          'endOfRange' => 5000
        }, {
          'entityId' => '552',
          'endOfRange' => 9000
        }, {
          'entityId' => '',
          'endOfRange' => 10000
        }],
        'audienceIds' => ['11154'],
        'forcedVariations' => {},
        'layerId' => '1'
      }, {
        'id' => '443',
        'key' => 'groupExperiment2',
        'status' => 'Running',
        'variations' => [{
          'id' => '661',
          'key' => 'var1exp2'
        }, {
          'id' => '662',
          'key' => 'var2exp2'
        }],
        'trafficAllocation' => [{
          'entityId' => '661',
          'endOfRange' => 5000
        }, {
          'entityId' => '662',
          'endOfRange' => 10000
        }],
        'audienceIds' => [],
        'forcedVariations' => {},
        'layerId' => '2'
      }]
    }, {
      'id' => '667',
      'policy' => 'overlapping',
      'trafficAllocation' => [],
      'experiments' => [{
        'id' => '444',
        'key' => 'overlappingGroupExperiment1',
        'status' => 'Running',
        'variations' => [{
          'id' => '553',
          'key' => 'overlappingvar1'
        }, {
          'id' => '554',
          'key' => 'overlappingvar2'
        }],
        'trafficAllocation' => [{
          'entityId' => '553',
          'endOfRange' => 1500
        }, {
          'entityId' => '554',
          'endOfRange' => 3000
        }],
        'audienceIds' => [],
        'forcedVariations' => {},
        'layerId' => '3'
      }]
    }],
    'experiments' => [{
      'key' => 'testExperiment',
      'status' => 'Running',
      'forcedVariations' => {
        'user1' => 'control',
        'user2' => 'variation'
      },
      'audienceIds' => [],
      'layerId' => '4',
      'trafficAllocation' => [{
        'entityId' => '111128',
        'endOfRange' => 4000
      }, {
        'entityId' => '111129',
        'endOfRange' => 9000
      }],
      'id' => '111127',
      'variations' => [{
        'key' => 'control',
        'id' => '111128'
      }, {
        'key' => 'variation',
        'id' => '111129'
      }]
    }, {
      'key' => 'testExperimentWithAudiences',
      'status' => 'Running',
      'forcedVariations' => {},
      'audienceIds' => ['11154'],
      'layerId' => '5',
      'trafficAllocation' => [{
        'entityId' => '122228',
        'endOfRange' => 4000,
      }, {
        'entityId' => '122229',
        'endOfRange' => 10000
      }],
      'id' => '122227',
      'variations' => [{
        'key' => 'controlWithAudience',
        'id' => '122228'
      }, {
        'key' => 'variationWithAudience',
        'id' => '122229'
      }]
    }, {
      'key' => 'testExperimentNotRunning',
      'status' => 'Not started',
      'forcedVariations' => {},
      'audienceIds' => [],
      'layerId' => '6',
      'trafficAllocation' => [{
        'entityId' => '133338',
        'endOfRange' => 4000
      }, {
        'entityId' => '133339',
        'endOfRange' => 10000
      }],
      'id' => '133337',
      'variations' => [{
        'key' => 'controlNotRunning',
        'id' => '133338'
      }, {
        'key' => 'variationNotRunning',
        'id' => '133339'
      }]
    }],
    'accountId' => '12001',
    'dimensions' => [{
      'key' => 'browser_type',
      'id' => '111094',
      'segmentId' => '5175100584230912'
    }],
    'audiences' => [{
      'name' => 'Firefox users',
      'conditions' => '["and", ["or", ["or", {"name" => "browser_type", "type" => "custom_dimension", "value" => "firefox"}]]]',
      'id' => '11154'
    }],
    'projectId' => '111001'
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
