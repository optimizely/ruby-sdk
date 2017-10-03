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
require 'spec_helper'
require 'optimizely/project_config'
require 'optimizely/exceptions'

describe Optimizely::ProjectConfig do
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:logger) { Optimizely::NoOpLogger.new }
  let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, logger, error_handler)}

  describe '.initialize' do
    it 'should initialize properties correctly upon creating project' do
      project_config = Optimizely::ProjectConfig.new(config_body_JSON, logger, error_handler)

      expect(project_config.account_id).to eq(config_body['accountId'])
      expect(project_config.attributes).to eq(config_body['attributes'])
      expect(project_config.audiences).to eq(config_body['audiences'])
      expect(project_config.events).to eq(config_body['events'])
      expect(project_config.groups).to eq(config_body['groups'])
      expect(project_config.project_id).to eq(config_body['projectId'])
      expect(project_config.revision).to eq(config_body['revision'])
      expect(project_config.parsing_succeeded).to be(true)

      expected_attribute_key_map = {
        'browser_type' => config_body['attributes'][0]
      }

      expected_audience_id_map = {
        '11154' => config_body['audiences'][0]
      }

      expected_event_key_map = {
        'test_event' => config_body['events'][0],
        'Total Revenue' => config_body['events'][1],
        'test_event_with_audience' => config_body['events'][2],
        'test_event_not_running' => config_body['events'][3]
      }

      expected_experiment_key_map = {
        'test_experiment' => config_body['experiments'][0],
        'test_experiment_not_started' => config_body['experiments'][1],
        'test_experiment_with_audience' => config_body['experiments'][2],
        'group1_exp1' => config_body['groups'][0]['experiments'][0].merge('groupId' => '101'),
        'group1_exp2' => config_body['groups'][0]['experiments'][1].merge('groupId' => '101'),
        'group2_exp1' => config_body['groups'][1]['experiments'][0].merge('groupId' => '102'),
        'group2_exp2' => config_body['groups'][1]['experiments'][1].merge('groupId' => '102')
      }

      expected_variation_id_map = {
        'test_experiment' => {
          '111128' => {
            'key' => 'control',
            'id' => '111128'
          },
          '111129' => {
            'key' => 'variation',
            'id' => '111129'
          }
        },
        'test_experiment_not_started' => {
          '100028' => {
            'key' => 'control_not_started',
            'id'=>'100028'
          },
          '100029' => {
            'key' => 'variation_not_started',
            'id' => '100029'
          }
        },
        'test_experiment_with_audience' => {
          '122228' => {
            'key' => 'control_with_audience',
            'id' => '122228'
          },
          '122229' => {
            'key' => 'variation_with_audience',
            'id' => '122229'
          }
        },
        'group1_exp1' => {
          '130001' => {
            'key' => 'g1_e1_v1',
            'id' => '130001'
          },
          '130002' => {
            'key' => 'g1_e1_v2',
            'id' => '130002'
          }
        },
        'group1_exp2' => {
          '130003' => {
            'key' => 'g1_e2_v1',
            'id' => '130003'
          },
          '130004' => {
            'key' => 'g1_e2_v2',
            'id' => '130004'
          }
        },
        'group2_exp1' => {
          '144443' => {
            'key' => 'g2_e1_v1',
            'id' => '144443'
          },
          '144444' => {
            'key' => 'g2_e1_v2',
            'id' => '144444'
          }
        },
        'group2_exp2' => {
          '144445' => {
            'key' => 'g2_e2_v1',
            'id' => '144445'
          },
          '144446' => {
            'key' => 'g2_e2_v2',
            'id' => '144446'
          }
        }
      }

      expected_variation_key_map = {
        'test_experiment' => {
          'control' => {
            'key' => 'control',
            'id' => '111128'
          },
          'variation' => {
            'key' => 'variation',
            'id' => '111129'
          }
        },
        'test_experiment_not_started' => {
          'control_not_started' => {
            'key' => 'control_not_started',
            'id'=>'100028'
          },
          'variation_not_started' => {
            'key' => 'variation_not_started',
            'id' => '100029'
          }
        },
        'test_experiment_with_audience' => {
          'control_with_audience' => {
            'key' => 'control_with_audience',
            'id' => '122228'
          },
          'variation_with_audience' => {
            'key' => 'variation_with_audience',
            'id' => '122229'
          }
        },
        'group1_exp1' => {
          'g1_e1_v1' => {
            'key' => 'g1_e1_v1',
            'id' => '130001'
          },
          'g1_e1_v2' => {
            'key' => 'g1_e1_v2',
            'id' => '130002'
          }
        },
        'group1_exp2' => {
          'g1_e2_v1' => {
            'key' => 'g1_e2_v1',
            'id' => '130003'
          },
          'g1_e2_v2' => {
            'key' => 'g1_e2_v2',
            'id' => '130004'
          }
        },
        'group2_exp1' => {
          'g2_e1_v1' => {
            'key' => 'g2_e1_v1',
            'id' => '144443'
          },
          'g2_e1_v2' => {
            'key' => 'g2_e1_v2',
            'id' => '144444'
          }
        },
        'group2_exp2' => {
          'g2_e2_v1' => {
            'key' => 'g2_e2_v1',
            'id' => '144445'
          },
          'g2_e2_v2' => {
            'key' => 'g2_e2_v2',
            'id' => '144446'
          }
        }
      }

      expect(project_config.attribute_key_map).to eq(expected_attribute_key_map)
      expect(project_config.audience_id_map).to eq(expected_audience_id_map)
      expect(project_config.event_key_map).to eq(expected_event_key_map)
      expect(project_config.experiment_key_map).to eq(expected_experiment_key_map)
      expect(project_config.variation_id_map).to eq(expected_variation_id_map)
      expect(project_config.variation_key_map).to eq(expected_variation_key_map)
    end
  end

  describe 'parsing_succeeded?' do
    let(:config_body_v2) { OptimizelySpec::VALID_CONFIG_BODY }
    let(:config_body_v2_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }

    it 'should be true for version 2' do
      project_config_v2 = Optimizely::ProjectConfig.new(config_body_v2_JSON, logger, error_handler)
      expect(project_config_v2.parsing_succeeded?).to be(true)
    end
  end

  describe '@logger' do
    let(:spy_logger) { spy('logger') }
    let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, spy_logger, error_handler)}

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

    describe 'get_experiment_ids_for_event' do
      it 'should log a message when provided event key is invalid' do
        config.get_experiment_ids_for_event('invalid_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Event 'invalid_key' is not in datafile.")
      end
    end

    describe 'get_audience_conditions_from_id' do
      it 'should log a message when provided audience ID is invalid' do
        config.get_audience_conditions_from_id('invalid_id')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Audience 'invalid_id' is not in datafile.")
      end
    end

    describe 'get_variation_key_from_id' do
      it 'should log a message when provided experiment key is invalid' do
        config.get_variation_key_from_id('invalid_key', 'some_variation')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment key 'invalid_key' is not in datafile.")
      end
      it 'should return nil when provided variation key is invalid' do
        expect(config.get_variation_key_from_id('test_experiment', 'invalid_variation')).to eq(nil)
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

    describe 'get_attribute_id' do
      it 'should log a message when provided attribute key is invalid' do
        config.get_attribute_id('invalid_attr')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Attribute key 'invalid_attr' is not in datafile.")
      end
    end
  end

  describe '@error_handler' do
    let(:raise_error_handler) { Optimizely::RaiseErrorHandler.new }
    let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, logger, raise_error_handler)}

     describe 'get_experiment_from_key' do
      it 'should raise an error when provided experiment key is invalid' do
        expect { config.get_experiment_from_key('invalid_key') }.to raise_error(Optimizely::InvalidExperimentError)
      end
    end

    describe 'get_experiment_ids_for_event' do
      it 'should raise an error when provided event key is invalid' do
        expect { config.get_experiment_ids_for_event('invalid_key') }.to raise_error(Optimizely::InvalidEventError)
      end
    end

    describe 'get_audience_conditions_from_id' do
      it 'should raise an error when provided audience ID is invalid' do
        expect { config.get_audience_conditions_from_id('invalid_key') }
               .to raise_error(Optimizely::InvalidAudienceError)
      end
    end

    describe 'get_variation_key_from_id' do
      it 'should raise an error when provided experiment key is invalid' do
        expect { config.get_variation_key_from_id('invalid_key', 'some_variation') }
               .to raise_error(Optimizely::InvalidExperimentError)
      end
    end

    describe 'get_variation_key_from_id' do
      it 'should raise an error when provided variation key is invalid' do
        expect { config.get_variation_key_from_id('test_experiment', 'invalid_variation') }
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

    describe 'get_attribute_id' do
      it 'should raise an error when provided attribute key is invalid' do
        expect { config.get_attribute_id('invalid_attr') }.to raise_error(Optimizely::InvalidAttributeError)
      end
    end
  end

  describe '#experiment_running' do
    let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, logger, error_handler)}

    it 'should return true if the experiment is running' do
      experiment = config.get_experiment_from_key('test_experiment')
      expect(config.experiment_running?(experiment)).to eq(true)
    end

    it 'should return false if the experiment is not running' do
      experiment = config.get_experiment_from_key('test_experiment_not_started')
      expect(config.experiment_running?(experiment)).to eq(false)
    end
  end

  # Only those log messages have been asserted, which are directly logged in these methods.
  # Messages that are logged in some internal function calls, are asserted in their respective function test cases. 
  describe 'get_forced_variation' do
    let(:spy_logger) { spy('logger') }
    let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, spy_logger, error_handler)}

    before(:example) do
      @user_id = "test_user"
      @invalid_experiment_key = "invalid_experiment"
      @invalid_variation_key = "invalid_variation"
      @valid_experiment = {id: '111127', key: "test_experiment"}
      @valid_variation = {id: '111128', key: "control"}
    end
    # User ID is nil
    it 'should log a message and return nil when user_id is passed as nil for get_forced_variation' do
      expect(config.get_forced_variation(@valid_experiment[:key], nil)).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG,
       "User ID is invalid")
    end
    # User ID is an empty string
    it 'should log a message and return nil when user_id is passed as empty string for get_forced_variation' do
      expect(config.get_forced_variation(@valid_experiment[:key], '')).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG,
       "User ID is invalid")
    end
    # User ID is not defined in the forced variation map
    it 'should log a message and return nil when user is not in forced variation map' do
      expect(config.get_forced_variation(@valid_experiment[:key], @user_id)).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG,
       "User '#{@user_id}' is not in the forced variation map.")
    end
    # Experiment key does not exist in the datafile
    it 'should return nil when experiment key is not in datafile' do
      expect(config.get_forced_variation(@invalid_experiment_key, @user_id)).to eq(nil)
    end
    # Experiment key is nil
    it 'should return nil when experiment_key is passed as nil for get_forced_variation' do
      expect(config.get_forced_variation(nil, @user_id)).to eq(nil)
    end
    # Experiment key is an empty string
    it 'should return nil when experiment_key is passed as empty string for get_forced_variation' do
      expect(config.get_forced_variation('', @user_id)).to eq(nil)
    end

  end

  # Only those log messages have been asserted, which are directly logged in these methods.
  # Messages that are logged in some internal function calls, are asserted in their respective function test cases.
  describe 'set_forced_variation' do
    let(:spy_logger) { spy('logger') }
    let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, spy_logger, error_handler)}

    before(:example) do
      @user_id = "test_user"
      @invalid_experiment_key = "invalid_experiment"
      @invalid_variation_key = "invalid_variation"
      @valid_experiment = {id: '111127', key: "test_experiment"}
      @valid_variation = {id: '111128', key: "control"}
    end

    # User ID is nil
    it 'should log a message when user_id is passed as nil' do
      expect(config.set_forced_variation(@valid_experiment[:key], nil, @valid_variation[:key])).to eq(false)
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG,
       "User ID is invalid")
    end
    # User ID is an empty string
    it 'should log a message and return false when user_id is passed as empty string' do
      expect(config.set_forced_variation(@valid_experiment[:key], '', @valid_variation[:key])).to eq(false)
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG,
       "User ID is invalid")
    end
    # Experiment key is nil
    it 'should return false when experiment_key is passed as nil' do
      expect(config.set_forced_variation(nil, @user_id, @valid_variation[:key])).to eq(false)
    end
    # Experiment key is an empty string
    it 'should return false when experiment_key is passed as empty string' do
      expect(config.set_forced_variation('', @user_id, @valid_variation[:key])).to eq(false)
    end
    # Experiment key does not exist in the datafile
    it 'return nil when experiment key is not in datafile' do
      expect(config.set_forced_variation(@invalid_experiment_key, @user_id, @valid_variation[:key])).to eq(false)
    end
    # Variation key is nil
    it 'should delete forced varaition maping, log a message and return true when variation_key is passed as nil' do
      expect(config.set_forced_variation(@valid_experiment[:key], @user_id, nil)).to eq(true)
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG,
       "Variation mapped to experiment '#{@valid_experiment[:key]}' has been removed for user '#{@user_id}'.")
    end
    # Variation key is an empty string
    it 'should delete forced varaition maping, log a message and return true when variation_key is passed as empty string' do
      expect(config.set_forced_variation(@valid_experiment[:key], @user_id, '')).to eq(true)
      expect(spy_logger).to have_received(:log).with(Logger::DEBUG,
       "Variation mapped to experiment '#{@valid_experiment[:key]}' has been removed for user '#{@user_id}'.")
    end
    # Variation key does not exist in the datafile
    it 'return false when variation_key is not in datafile' do
      expect(config.set_forced_variation(@valid_experiment[:key], @user_id, @invalid_variation_key)).to eq(false)
    end
  end

  describe 'set/get forced variations multiple calls' do

    let(:spy_logger) { spy('logger') }
    let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, spy_logger, error_handler)}

    before(:example) do
      @user_id = "test_user"
      @user_id_2 = "test_user_2"
      @invalid_experiment_key = "invalid_experiment"
      @invalid_variation_key = "invalid_variation"
      @valid_experiment = {id: '111127', key: "test_experiment"}
      @valid_variation = {id: '111128', key: "control"}
      @valid_variation_2 = {id: '111129', key: "variation"}
      @valid_experiment_2 = {id: '122227', key: "test_experiment_with_audience"}
      @valid_variation_for_exp_2 = {id: '122228', key: "control_with_audience"}
    end

    # Call set variation with different variations on one user/experiment to confirm that each set is expected.
    it 'should set and return expected variations when different variations are set and removed for one user/experiment' do
      expect(config.set_forced_variation(@valid_experiment[:key], @user_id, @valid_variation[:key])).to eq(true)
      variation = config.get_forced_variation(@valid_experiment[:key], @user_id)                                          
      expect(variation['id']).to eq(@valid_variation[:id])
      expect(variation['key']).to eq(@valid_variation[:key])      

      expect(config.set_forced_variation(@valid_experiment[:key], @user_id, @valid_variation_2[:key])).to eq(true)
      variation = config.get_forced_variation(@valid_experiment[:key], @user_id)
      expect(variation['id']).to eq(@valid_variation_2[:id])
      expect(variation['key']).to eq(@valid_variation_2[:key])                                   

      expect(config.set_forced_variation(@valid_experiment[:key], @user_id,  '')).to eq(true)
      expect(config.get_forced_variation(@valid_experiment[:key], @user_id)).to eq(nil)
    end

    # Set variation on multiple experiments for one user.
    it 'should set and return expected variations when variation is set for multiple experiments for one user' do
      expect(config.set_forced_variation(@valid_experiment[:key], @user_id, @valid_variation[:key])).to eq(true)
      variation = config.get_forced_variation(@valid_experiment[:key], @user_id)
      expect(variation['id']).to eq(@valid_variation[:id])
      expect(variation['key']).to eq(@valid_variation[:key])

      expect(config.set_forced_variation(@valid_experiment_2[:key], @user_id, @valid_variation_for_exp_2[:key])).to eq(true)
      variation = config.get_forced_variation(@valid_experiment_2[:key], @user_id)
      expect(variation['id']).to eq(@valid_variation_for_exp_2[:id])
      expect(variation['key']).to eq(@valid_variation_for_exp_2[:key])
    end

    # Set variations for multiple users.
    it 'should set and return expected variations when variations are set for multiple users' do

      expect(config.set_forced_variation(@valid_experiment[:key], @user_id, @valid_variation[:key])).to eq(true)
      variation = config.get_forced_variation(@valid_experiment[:key], @user_id)
      expect(variation['id']).to eq(@valid_variation[:id])
      expect(variation['key']).to eq(@valid_variation[:key])

      expect(config.set_forced_variation(@valid_experiment[:key], @user_id_2, @valid_variation[:key])).to eq(true)
      variation = config.get_forced_variation(@valid_experiment[:key], @user_id_2)
      expect(variation['id']).to eq(@valid_variation[:id])
      expect(variation['key']).to eq(@valid_variation[:key])
    end

  end
end
