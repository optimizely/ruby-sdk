# frozen_string_literal: true

#
#    Copyright 2016-2018, Optimizely and contributors
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
        'STRING' => 'string'
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
    end
  end
end
