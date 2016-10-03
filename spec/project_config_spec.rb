require 'spec_helper'
require 'optimizely/project_config'
require 'optimizely/exceptions'

describe Optimizely::ProjectConfig do
  let(:config_body) { OptimizelySpec::V2_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::V2_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:logger) { Optimizely::NoOpLogger.new }
  let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, logger, error_handler)}

  describe '#user_in_forced_variations' do
    it 'should return false when the experiment has no forced variations' do
      expect(config.user_in_forced_variation?('group1_exp1', 'test_user')).to be(false)
    end

    it 'should return false when the user is not in a forced variation' do
      expect(config.user_in_forced_variation?('test_experiment', 'test_user')).to be(false)
    end

    it 'should return true when the user is in a forced variation' do
      expect(config.user_in_forced_variation?('test_experiment', 'forced_user1')).to be(true)
    end
  end

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

  describe '@logger' do
    let(:spy_logger) { spy('logger') }
    let(:config) { Optimizely::ProjectConfig.new(config_body_JSON, spy_logger, error_handler)}

    describe 'get_experiment_id' do
      it 'should log a message when provided experiment key is invalid' do
        config.get_experiment_id('invalid_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment key 'invalid_key' is not in datafile.")
      end
    end

    describe 'experiment_running?' do
      it 'should log a message when provided experiment key is invalid' do
        config.experiment_running?('invalid_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment key 'invalid_key' is not in datafile.")
      end
    end

    describe 'get_experiment_ids_for_goal' do
      it 'should log a message when provided goal key is invalid' do
        config.get_experiment_ids_for_goal('invalid_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Event 'invalid_key' is not in datafile.")
      end
    end

    describe 'get_traffic_allocation' do
      it 'should log a message when provided experiment key is invalid' do
        config.get_traffic_allocation('invalid_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment key 'invalid_key' is not in datafile.")
      end
    end

    describe 'get_audience_ids_for_experiment' do
      it 'should log a message when provided experiment key is invalid' do
        config.get_audience_ids_for_experiment('invalid_key')
        expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                       "Experiment key 'invalid_key' is not in datafile.")
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

     describe 'get_experiment_id' do
      it 'should raise an error when provided experiment key is invalid' do
        expect { config.get_experiment_id('invalid_key') }.to raise_error(Optimizely::InvalidExperimentError)
      end
    end

    describe 'experiment_running?' do
      it 'should raise an error when provided experiment key is invalid' do
        expect { config.experiment_running?('invalid_key') }.to raise_error(Optimizely::InvalidExperimentError)
      end
    end

    describe 'get_experiment_ids_for_goal' do
      it 'should raise an error when provided goal key is invalid' do
        expect { config.get_experiment_ids_for_goal('invalid_key') }.to raise_error(Optimizely::InvalidEventError)
      end
    end

    describe 'get_traffic_allocation' do
      it 'should raise an error when provided experiment key is invalid' do
        expect { config.get_traffic_allocation('invalid_key') }.to raise_error(Optimizely::InvalidExperimentError)
      end
    end

    describe 'get_audience_ids_for_experiment' do
      it 'should raise an error when provided experiment key is invalid' do
        expect { config.get_audience_ids_for_experiment('invalid_key') }
               .to raise_error(Optimizely::InvalidExperimentError)
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

    describe 'get_attribute_id' do
      it 'should raise an error when provided attribute key is invalid' do
        expect { config.get_attribute_id('invalid_attr') }.to raise_error(Optimizely::InvalidAttributeError)
      end
    end
  end
end
