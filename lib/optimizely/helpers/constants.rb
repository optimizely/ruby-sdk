# frozen_string_literal: true

#
#    Copyright 2016-2020, 2022, Optimizely and contributors
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
  module Helpers
    module Constants
      JSON_SCHEMA_V2 = {
        'type' => 'object',
        'properties' => {
          'projectId' => {
            'type' => 'string'
          },
          'accountId' => {
            'type' => 'string'
          },
          'groups' => {
            'type' => 'array',
            'items' => {
              'type' => 'object',
              'properties' => {
                'id' => {
                  'type' => 'string'
                },
                'policy' => {
                  'type' => 'string'
                },
                'trafficAllocation' => {
                  'type' => 'array',
                  'items' => {
                    'type' => 'object',
                    'properties' => {
                      'entityId' => {
                        'type' => 'string'
                      },
                      'endOfRange' => {
                        'type' => 'integer'
                      }
                    },
                    'required' => %w[
                      entityId
                      endOfRange
                    ]
                  }
                },
                'experiments' => {
                  'type' => 'array',
                  'items' => {
                    'type' => 'object',
                    'properties' => {
                      'id' => {
                        'type' => 'string'
                      },
                      'layerId' => {
                        'type' => 'string'
                      },
                      'key' => {
                        'type' => 'string'
                      },
                      'status' => {
                        'type' => 'string'
                      },
                      'variations' => {
                        'type' => 'array',
                        'items' => {
                          'type' => 'object',
                          'properties' => {
                            'id' => {
                              'type' => 'string'
                            },
                            'key' => {
                              'type' => 'string'
                            }
                          },
                          'required' => %w[
                            id
                            key
                          ]
                        }
                      },
                      'trafficAllocation' => {
                        'type' => 'array',
                        'items' => {
                          'type' => 'object',
                          'properties' => {
                            'entityId' => {
                              'type' => 'string'
                            },
                            'endOfRange' => {
                              'type' => 'integer'
                            }
                          },
                          'required' => %w[
                            entityId
                            endOfRange
                          ]
                        }
                      },
                      'audienceIds' => {
                        'type' => 'array',
                        'items' => {
                          'type' => 'string'
                        }
                      },
                      'forcedVariations' => {
                        'type' => 'object'
                      }
                    },
                    'required' => %w[
                      id
                      layerId
                      key
                      status
                      variations
                      trafficAllocation
                      audienceIds
                      forcedVariations
                    ]
                  }
                }
              },
              'required' => %w[
                id
                policy
                trafficAllocation
                experiments
              ]
            }
          },
          'experiments' => {
            'type' => 'array',
            'items' => {
              'type' => 'object',
              'properties' => {
                'id' => {
                  'type' => 'string'
                },
                'key' => {
                  'type' => 'string'
                },
                'status' => {
                  'type' => 'string'
                },
                'layerId' => {
                  'type' => 'string'
                },
                'variations' => {
                  'type' => 'array',
                  'items' => {
                    'type' => 'object',
                    'properties' => {
                      'id' => {
                        'type' => 'string'
                      },
                      'key' => {
                        'type' => 'string'
                      }
                    },
                    'required' => %w[
                      id
                      key
                    ]
                  }
                },
                'trafficAllocation' => {
                  'type' => 'array',
                  'items' => {
                    'type' => 'object',
                    'properties' => {
                      'entityId' => {
                        'type' => 'string'
                      },
                      'endOfRange' => {
                        'type' => 'integer'
                      }
                    },
                    'required' => %w[
                      entityId
                      endOfRange
                    ]
                  }
                },
                'audienceIds' => {
                  'type' => 'array',
                  'items' => {
                    'type' => 'string'
                  }
                },
                'forcedVariations' => {
                  'type' => 'object'
                }
              },
              'required' => %w[
                id
                key
                variations
                trafficAllocation
                audienceIds
                forcedVariations
                status
                layerId
              ]
            }
          },
          'events' => {
            'type' => 'array',
            'items' => {
              'type' => 'object',
              'properties' => {
                'key' => {
                  'type' => 'string'
                },
                'experimentIds' => {
                  'type' => 'array',
                  'items' => {
                    'type' => 'string'
                  }
                },
                'id' => {
                  'type' => 'string'
                }
              },
              'required' => %w[
                key
                experimentIds
                id
              ]
            }
          },
          'audiences' => {
            'type' => 'array',
            'items' => {
              'type' => 'object',
              'properties' => {
                'id' => {
                  'type' => 'string'
                },
                'name' => {
                  'type' => 'string'
                },
                'conditions' => {
                  'type' => 'string'
                }
              },
              'required' => %w[
                id
                name
                conditions
              ]
            }
          },
          'attributes' => {
            'type' => 'array',
            'items' => {
              'type' => 'object',
              'properties' => {
                'id' => {
                  'type' => 'string'
                },
                'key' => {
                  'type' => 'string'
                }
              },
              'required' => %w[
                id
                key
              ]
            }
          },
          'version' => {
            'type' => 'string'
          },
          'revision' => {
            'type' => 'string'
          },
          'integrations' => {
            'type' => 'array',
            'items' => {
              'type' => 'object',
              'properties' => {
                'key' => {
                  'type' => 'string'
                },
                'host' => {
                  'type' => 'string'
                },
                'publicKey' => {
                  'type' => 'string'
                }
              },
              'required' => %w[key]
            }
          }
        },
        'required' => %w[
          projectId
          accountId
          experiments
          events
          groups
          audiences
          attributes
          version
          revision
        ]
      }.freeze

      VARIABLE_TYPES = {
        'BOOLEAN' => 'boolean',
        'DOUBLE' => 'double',
        'INTEGER' => 'integer',
        'STRING' => 'string',
        'JSON' => 'json'
      }.freeze

      INPUT_VARIABLES = {
        'FEATURE_FLAG_KEY' => 'Feature flag key',
        'EXPERIMENT_KEY' => 'Experiment key',
        'USER_ID' => 'User ID',
        'VARIATION_KEY' => 'Variation key',
        'VARIABLE_KEY' => 'Variable key',
        'VARIABLE_TYPE' => 'Variable type'
      }.freeze

      CONTROL_ATTRIBUTES = {
        'BOT_FILTERING' => '$opt_bot_filtering',
        'BUCKETING_ID' => '$opt_bucketing_id',
        'USER_AGENT' => '$opt_user_agent'
      }.freeze

      SUPPORTED_VERSIONS = {
        'v2' => '2',
        'v3' => '3',
        'v4' => '4'
      }.freeze

      ATTRIBUTE_VALID_TYPES = [FalseClass, Float, Integer, String, TrueClass].freeze

      FINITE_NUMBER_LIMIT = 2**53

      AUDIENCE_EVALUATION_LOGS = {
        'AUDIENCE_EVALUATION_RESULT' => "Audience '%s' evaluated to %s.",
        'EVALUATING_AUDIENCE' => "Starting to evaluate audience '%s' with conditions: %s.",
        'INFINITE_ATTRIBUTE_VALUE' => 'Audience condition %s evaluated to UNKNOWN because the number value ' \
        "for user attribute '%s' is not in the range [-2^53, +2^53].",
        'INVALID_SEMANTIC_VERSION' => 'Audience condition %s evaluated as UNKNOWN because an invalid semantic version ' \
        "was passed for user attribute '%s'.",
        'MISSING_ATTRIBUTE_VALUE' => 'Audience condition %s evaluated as UNKNOWN because no value ' \
        "was passed for user attribute '%s'.",
        'NULL_ATTRIBUTE_VALUE' => 'Audience condition %s evaluated to UNKNOWN because a nil value was passed ' \
        "for user attribute '%s'.",
        'UNEXPECTED_TYPE' => "Audience condition %s evaluated as UNKNOWN because a value of type '%s' " \
        "was passed for user attribute '%s'.",
        'UNKNOWN_CONDITION_TYPE' => 'Audience condition %s uses an unknown condition type. You may need ' \
        'to upgrade to a newer release of the Optimizely SDK.',
        'UNKNOWN_CONDITION_VALUE' => 'Audience condition %s has an unsupported condition value. You may need ' \
        'to upgrade to a newer release of the Optimizely SDK.',
        'UNKNOWN_MATCH_TYPE' => 'Audience condition %s uses an unknown match type. You may need ' \
        'to upgrade to a newer release of the Optimizely SDK.'
      }.freeze

      EXPERIMENT_AUDIENCE_EVALUATION_LOGS = {
        'AUDIENCE_EVALUATION_RESULT_COMBINED' => "Audiences for experiment '%s' collectively evaluated to %s.",
        'EVALUATING_AUDIENCES_COMBINED' => "Evaluating audiences for experiment '%s': %s."
      }.merge(AUDIENCE_EVALUATION_LOGS).freeze

      ROLLOUT_AUDIENCE_EVALUATION_LOGS = {
        'AUDIENCE_EVALUATION_RESULT_COMBINED' => "Audiences for rule '%s' collectively evaluated to %s.",
        'EVALUATING_AUDIENCES_COMBINED' => "Evaluating audiences for rule '%s': %s."
      }.merge(AUDIENCE_EVALUATION_LOGS).freeze

      ODP_LOGS = {
        FETCH_SEGMENTS_FAILED: 'Audience segments fetch failed (%s).',
        ODP_EVENT_FAILED: 'ODP event send failed (%s).',
        ODP_NOT_ENABLED: 'ODP is not enabled.',
        ODP_NOT_INTEGRATED: 'ODP is not integrated.',
        ODP_EVENT_NOT_DISPATCHED: "ODP '%s' event is not dispatched (%s)"
      }.freeze

      DECISION_NOTIFICATION_TYPES = {
        'AB_TEST' => 'ab-test',
        'FEATURE' => 'feature',
        'FEATURE_TEST' => 'feature-test',
        'FEATURE_VARIABLE' => 'feature-variable',
        'FLAG' => 'flag',
        'ALL_FEATURE_VARIABLES' => 'all-feature-variables'
      }.freeze

      CONFIG_MANAGER = {
        'DATAFILE_URL_TEMPLATE' => 'https://cdn.optimizely.com/datafiles/%s.json',
        'AUTHENTICATED_DATAFILE_URL_TEMPLATE' => 'https://config.optimizely.com/datafiles/auth/%s.json',
        # Default time in seconds to block the 'config' method call until 'config' instance has been initialized.
        'DEFAULT_BLOCKING_TIMEOUT' => 15,
        # Default config update interval of 5 minutes
        'DEFAULT_UPDATE_INTERVAL' => 5 * 60,
        # Maximum update interval or blocking timeout: 30 days
        'MAX_SECONDS_LIMIT' => 2_592_000,
        # Minimum update interval or blocking timeout: 1 second
        'MIN_SECONDS_LIMIT' => 1,
        # Time in seconds before which request for datafile times out
        'REQUEST_TIMEOUT' => 10
      }.freeze

      EVENT_DISPATCH_CONFIG = {
        REQUEST_TIMEOUT: 10
      }.freeze

      ODP_GRAPHQL_API_CONFIG = {
        REQUEST_TIMEOUT: 10
      }.freeze

      ODP_REST_API_CONFIG = {
        REQUEST_TIMEOUT: 10
      }.freeze

      ODP_SEGMENTS_CACHE_CONFIG = {
        DEFAULT_CAPACITY: 10_000,
        DEFAULT_TIMEOUT_SECONDS: 600
      }.freeze

      ODP_MANAGER_CONFIG = {
        KEY_FOR_USER_ID: 'fs_user_id',
        EVENT_TYPE: 'fullstack'
      }.freeze

      ODP_CONFIG_STATE = {
        UNDETERMINED: 'UNDETERMINED',
        INTEGRATED: 'INTEGRATED',
        NOT_INTEGRATED: 'NOT_INTEGRATED'
      }.freeze

      ODP_EVENT_MANAGER = {
        DEFAULT_QUEUE_CAPACITY: 10_000,
        DEFAULT_BATCH_SIZE: 10,
        DEFAULT_FLUSH_INTERVAL_SECONDS: 1,
        DEFAULT_RETRY_COUNT: 3
      }.freeze

      HTTP_HEADERS = {
        'IF_MODIFIED_SINCE' => 'If-Modified-Since',
        'LAST_MODIFIED' => 'Last-Modified'
      }.freeze
    end
  end
end
