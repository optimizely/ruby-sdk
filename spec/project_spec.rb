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
require 'spec_helper'
require 'optimizely'
require 'optimizely/audience'
require 'optimizely/helpers/validator'
require 'optimizely/exceptions'
require 'optimizely/version'

describe 'Optimizely' do
  let(:config_body) { OptimizelySpec::VALID_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:config_body_invalid_JSON) { OptimizelySpec::INVALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:version) { Optimizely::VERSION }
  let(:impression_log_url) { 'https://logx.optimizely.com/v1/events' }
  let(:conversion_log_url) { 'https://logx.optimizely.com/v1/events' }
  let(:project_instance) { Optimizely::Project.new(config_body_JSON, nil, spy_logger, error_handler) }
  let(:time_now) { Time.now }
  let(:post_headers) { {'Content-Type' => 'application/json'} }

  it 'has a version number' do
    expect(Optimizely::VERSION).not_to be_nil
  end

  it 'has engine value' do
    expect(Optimizely::CLIENT_ENGINE).not_to be_nil
  end

  describe '.initialize' do
    it 'should take in a custom logger when instantiating Project class' do
      class CustomLogger
        def log(log_message)
          log_message
        end
      end

      logger = CustomLogger.new
      instance_with_logger = Optimizely::Project.new(config_body_JSON, nil, logger)
      expect(instance_with_logger.logger.log('test_message')).to eq('test_message')
    end

    it 'should take in a custom error handler when instantiating Project class' do
      class CustomErrorHandler
        def handle_error(error)
          error
        end
      end

      error_handler = CustomErrorHandler.new
      instance_with_error_handler = Optimizely::Project.new(config_body_JSON, nil, nil, error_handler)
      expect(instance_with_error_handler.error_handler.handle_error('test_message')). to eq('test_message')
    end

    it 'should log an error when datafile is null' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      Optimizely::Project.new(nil)
    end

    it 'should log an error when datafile is empty' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      Optimizely::Project.new('')
    end

    it 'should log an error when given a datafile that does not conform to the schema' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      Optimizely::Project.new('{"foo": "bar"}')
    end

    it 'should log an error when given an invalid logger' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided logger is in an invalid format.')

      class InvalidLogger; end
      Optimizely::Project.new(config_body_JSON, nil, InvalidLogger.new)
    end

    it 'should log an error when given an invalid event_dispatcher' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided event_dispatcher is in an invalid format.')

      class InvalidEventDispatcher; end
      Optimizely::Project.new(config_body_JSON, InvalidEventDispatcher.new)
    end

    it 'should log an error when given an invalid error_handler' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided error_handler is in an invalid format.')

      class InvalidErrorHandler; end
      Optimizely::Project.new(config_body_JSON, nil, nil, InvalidErrorHandler.new)
    end

    it 'should not validate the JSON schema of the datafile when skip_json_validation is true' do
      expect(Optimizely::Helpers::Validator).not_to receive(:datafile_valid?)

      Optimizely::Project.new(config_body_JSON, nil, nil, nil, true)
    end

    it 'should log and raise an error when provided a datafile that is not JSON and skip_json_validation is true' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect_any_instance_of(Optimizely::RaiseErrorHandler).to receive(:handle_error).once.with(Optimizely::InvalidInputError)

      Optimizely::Project.new('this is not JSON', nil, nil, Optimizely::RaiseErrorHandler.new, true)
    end

    it 'should log an error when provided an invalid JSON datafile and skip_json_validation is true' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')

      Optimizely::Project.new('{"version": "2", "foo": "bar"}', nil, nil, nil, true)
    end

    it 'should log and raise an error when provided a datafile of unsupported version' do
      config_body_invalid_json = JSON.parse(config_body_invalid_JSON)
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, "This version of the Ruby SDK does not support the given datafile version: #{config_body_invalid_json['version']}.")
      expect_any_instance_of(Optimizely::RaiseErrorHandler).to receive(:handle_error).once.with(Optimizely::InvalidDatafileVersionError)

      Optimizely::Project.new(config_body_invalid_JSON, nil, nil, Optimizely::RaiseErrorHandler.new, true)
    end
  end

  describe '#activate' do
    before(:example) do
      allow(Time).to receive(:now).and_return(time_now)
      allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')

      @expected_activate_params = {
        account_id: '12001',
        project_id: '111001',
        visitors: [{
          attributes: [{
            entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
            key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
            type: 'custom',
            value: true
          }],
          snapshots: [{
            decisions: [{
              campaign_id: '1',
              experiment_id: '111127',
              variation_id: '111128'
            }],
            events: [{
              entity_id: '1',
              timestamp: (time_now.to_f * 1000).to_i,
              key: 'campaign_activated',
              uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c'
            }]
          }],
          visitor_id: 'test_user'
        }],
        anonymize_ip: false,
        revision: '42',
        client_name: Optimizely::CLIENT_ENGINE,
        enrich_decisions: true,
        client_version: Optimizely::VERSION
      }
    end

    it 'should properly activate a user, invoke Event object with right params, and return variation' do
      params = @expected_activate_params

      variation_to_return = project_instance.config.get_variation_from_id('test_experiment', '111128')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.config).to receive(:get_audience_ids_for_experiment)
        .with('test_experiment')
        .and_return([])

      stub_request(:post, impression_log_url).with(query: params)

      expect(project_instance.activate('test_experiment', 'test_user')).to eq('control')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
      expect(project_instance.decision_service.bucketer).to have_received(:bucket).once
    end

    it 'should properly activate a user, invoke Event object with right params, and return variation after a forced variation call' do
      params = @expected_activate_params

      project_instance.config.set_forced_variation('test_experiment', 'test_user', 'control')
      variation_to_return = project_instance.config.get_forced_variation('test_experiment', 'test_user')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.config).to receive(:get_audience_ids_for_experiment)
        .with('test_experiment')
        .and_return([])

      stub_request(:post, impression_log_url).with(query: params)

      expect(project_instance.activate('test_experiment', 'test_user')).to eq('control')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
    end

    it 'should properly activate a user, (with attributes provided) when there is an audience match' do
      params = @expected_activate_params
      params[:visitors][0][:attributes].unshift(
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'firefox'
      )
      params[:visitors][0][:snapshots][0][:decisions] = [{
        campaign_id: '3',
        experiment_id: '122227',
        variation_id: '122228'
      }]
      params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '3'

      variation_to_return = project_instance.config.get_variation_from_id('test_experiment_with_audience', '122228')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

      expect(project_instance.activate('test_experiment_with_audience', 'test_user', 'browser_type' => 'firefox'))
        .to eq('control_with_audience')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
      expect(project_instance.decision_service.bucketer).to have_received(:bucket).once
    end

    describe '.typed audiences' do
      before(:example) do
        @project_typed_audience_instance = Optimizely::Project.new(JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES), nil, spy_logger, error_handler)
        @expected_activate_params = {
          account_id: '4879520872',
          project_id: '11624721371',
          visitors: [
            {
              attributes: [
                {
                  entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
                  key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
                  type: 'custom',
                  value: false
                }
              ],
              snapshots: [
                {
                  events: [
                    {
                      entity_id: '1',
                      timestamp: (time_now.to_f * 1000).to_i,
                      key: 'campaign_activated',
                      uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c'
                    }
                  ]
                }
              ],
              visitor_id: 'test_user'
            }
          ],
          anonymize_ip: false,
          revision: '3',
          client_name: Optimizely::CLIENT_ENGINE,
          enrich_decisions: true,
          client_version: Optimizely::VERSION
        }
      end

      it 'should properly activate a user, (with attributes provided) when there is a typed audience with exact match type string' do
        params = @expected_activate_params

        params[:visitors][0][:attributes].unshift(
          entity_id: '594015',
          key: 'house',
          type: 'custom',
          value: 'Gryffindor'
        )
        params[:visitors][0][:snapshots][0][:decisions] = [{
          campaign_id: '1630555627',
          experiment_id: '1323241597',
          variation_id: '1423767503'
        }]
        params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '1630555627'

        variation_to_return = @project_typed_audience_instance.config.get_variation_from_id('typed_audience_experiment', '1423767503')
        allow(@project_typed_audience_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        # Should be included via exact match string audience with id '3468206642'
        expect(@project_typed_audience_instance.activate('typed_audience_experiment', 'test_user', 'house' => 'Gryffindor'))
          .to eq('A')
        expect(@project_typed_audience_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
        expect(@project_typed_audience_instance.decision_service.bucketer).to have_received(:bucket).once
      end

      it 'should properly activate a user, (with attributes provided) when there is a typed audience with exact match type number' do
        params = @expected_activate_params

        params[:visitors][0][:attributes].unshift(
          entity_id: '594016',
          key: 'lasers',
          type: 'custom',
          value: 45.5
        )
        params[:visitors][0][:snapshots][0][:decisions] = [{
          campaign_id: '1630555627',
          experiment_id: '1323241597',
          variation_id: '1423767503'
        }]
        params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '1630555627'

        variation_to_return = @project_typed_audience_instance.config.get_variation_from_id('typed_audience_experiment', '1423767503')
        allow(@project_typed_audience_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        # Should be included via exact match number audience with id '3468206646'
        expect(@project_typed_audience_instance.activate('typed_audience_experiment', 'test_user', 'lasers' => 45.5))
          .to eq('A')
        expect(@project_typed_audience_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
        expect(@project_typed_audience_instance.decision_service.bucketer).to have_received(:bucket).once
      end

      it 'should return nil when typed audience conditions mismatch' do
        variation_to_return = @project_typed_audience_instance.config.get_variation_from_id('typed_audience_experiment', '1423767503')
        allow(@project_typed_audience_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        expect(@project_typed_audience_instance.activate('typed_audience_experiment', 'test_user', 'house' => 'Hufflepuff'))
          .to eq(nil)
        expect(@project_typed_audience_instance.event_dispatcher).not_to have_received(:dispatch_event)
        expect(@project_typed_audience_instance.decision_service.bucketer).not_to have_received(:bucket)
      end

      it 'should properly activate a user, (with attributes provided) when there is a complex audience match' do
        # Should be included via substring match string audience with id '3988293898', and
        # exact match number audience with id '3468206646'
        user_attributes = {'house' => 'Welcome to Slytherin!', 'lasers' => 45.5}

        params = @expected_activate_params

        params[:visitors][0][:attributes].unshift(
          {
            entity_id: '594015',
            key: 'house',
            type: 'custom',
            value: 'Welcome to Slytherin!'
          },
          entity_id: '594016',
          key: 'lasers',
          type: 'custom',
          value: 45.5
        )

        params[:visitors][0][:snapshots][0][:decisions] = [{
          campaign_id: '1323241598',
          experiment_id: '1323241598',
          variation_id: '1423767504'
        }]
        params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '1323241598'

        variation_to_return = @project_typed_audience_instance.config.get_variation_from_id('audience_combinations_experiment', '1423767504')
        allow(@project_typed_audience_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        expect(@project_typed_audience_instance.activate('audience_combinations_experiment', 'test_user', user_attributes))
          .to eq('A')
        expect(@project_typed_audience_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
        expect(@project_typed_audience_instance.decision_service.bucketer).to have_received(:bucket).once
      end

      it 'should return nil when complex audience conditions do not match' do
        user_attributes = {'house' => 'Hufflepuff', 'lasers' => 45.5}
        # variation_to_return = @project_typed_audience_instance.config.get_variation_from_id('audience_combinations_experiment', '1423767504')
        allow(@project_typed_audience_instance.decision_service.bucketer).to receive(:bucket)
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        expect(@project_typed_audience_instance.activate('audience_combinations_experiment', 'test_user', user_attributes))
          .to eq(nil)
        expect(@project_typed_audience_instance.event_dispatcher).not_to have_received(:dispatch_event)
        expect(@project_typed_audience_instance.decision_service.bucketer).not_to have_received(:bucket)
      end
    end

    it 'should properly activate a user, (with attributes of valid types) when there is an audience match' do
      params = @expected_activate_params
      params[:visitors][0][:attributes].unshift(
        {
          entity_id: '111094',
          key: 'browser_type',
          type: 'custom',
          value: 'firefox'
        }, {
          entity_id: '111095',
          key: 'boolean_key',
          type: 'custom',
          value: true
        }, {
          entity_id: '111096',
          key: 'integer_key',
          type: 'custom',
          value: 5
        },
        entity_id: '111097',
        key: 'double_key',
        type: 'custom',
        value: 5.5
      )
      params[:visitors][0][:snapshots][0][:decisions] = [{
        campaign_id: '3',
        experiment_id: '122227',
        variation_id: '122228'
      }]
      params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '3'

      variation_to_return = project_instance.config.get_variation_from_id('test_experiment_with_audience', '122228')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

      attributes = {
        'browser_type' => 'firefox',
        'boolean_key' => true,
        'integer_key' => 5,
        'double_key' => 5.5
      }

      expect(project_instance.activate('test_experiment_with_audience', 'test_user', attributes))
        .to eq('control_with_audience')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
      expect(project_instance.decision_service.bucketer).to have_received(:bucket).once
    end

    it 'should properly activate a user, (with attributes of invalid types) when there is an audience match' do
      params = @expected_activate_params
      params[:visitors][0][:attributes].unshift(
        {
          entity_id: '111094',
          key: 'browser_type',
          type: 'custom',
          value: 'firefox'
        },
        entity_id: '111095',
        key: 'boolean_key',
        type: 'custom',
        value: true
      )
      params[:visitors][0][:snapshots][0][:decisions] = [{
        campaign_id: '3',
        experiment_id: '122227',
        variation_id: '122228'
      }]
      params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '3'

      variation_to_return = project_instance.config.get_variation_from_id('test_experiment_with_audience', '122228')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

      attributes = {
        'browser_type' => 'firefox',
        'boolean_key' => true,
        'integer_key' => nil,
        'double_key' => {}
      }

      expect(project_instance.activate('test_experiment_with_audience', 'test_user', attributes))
        .to eq('control_with_audience')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
      expect(project_instance.decision_service.bucketer).to have_received(:bucket).once
    end

    it 'should properly activate a user, (with attributes provided) when there is an audience match after a force variation call' do
      params = @expected_activate_params
      params[:visitors][0][:attributes].unshift(
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'firefox'
      )
      params[:visitors][0][:snapshots][0][:decisions] = [{
        campaign_id: '3',
        experiment_id: '122227',
        variation_id: '122229'
      }]
      params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '3'

      project_instance.config.set_forced_variation('test_experiment_with_audience', 'test_user', 'variation_with_audience')
      variation_to_return = project_instance.config.get_forced_variation('test_experiment', 'test_user')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

      expect(project_instance.activate('test_experiment_with_audience', 'test_user', 'browser_type' => 'firefox'))
        .to eq('variation_with_audience')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
    end

    it 'should return nil when experiment status is not "Running"' do
      expect(project_instance.activate('test_experiment_not_started', 'test_user')).to eq(nil)
    end

    it 'should return nil when audience conditions do not match' do
      user_attributes = {'browser_type' => 'chrome'}
      expect(project_instance.activate('test_experiment_with_audience', 'test_user', user_attributes)).to eq(nil)
    end

    it 'should return nil when attributes are invalid' do
      allow(project_instance).to receive(:attributes_valid?).and_return(false)
      expect(project_instance.activate('test_experiment_with_audience', 'test_user2', 'invalid')).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Not activating user 'test_user2'.")
    end

    it 'should call inputs_valid? with the proper arguments in activate' do
      expect(Optimizely::Helpers::Validator).to receive(:inputs_valid?).with(
        {
          experiment_key: 'test_experiment_with_audience',
          user_id: 'test_user'
        }, spy_logger, Logger::ERROR
      )
      project_instance.activate('test_experiment_with_audience', 'test_user')
    end

    it 'should log return nil when user ID is non string' do
      expect(project_instance.activate('test_experiment_with_audience', nil)).to eq(nil)
      expect(project_instance.activate('test_experiment_with_audience', 5)).to eq(nil)
      expect(project_instance.activate('test_experiment_with_audience', 5.5)).to eq(nil)
      expect(project_instance.activate('test_experiment_with_audience', true)).to eq(nil)
      expect(project_instance.activate('test_experiment_with_audience', {})).to eq(nil)
      expect(project_instance.activate('test_experiment_with_audience', [])).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'User ID is invalid').exactly(6).times
    end

    it 'should return false when invalid inputs are passed' do
      expect(Optimizely::Helpers::Validator.inputs_valid?({})).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?([])).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?(2)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?(2.0)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?('2.0')).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?('')).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?(true)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?(false)).to eq(false)
    end

    it 'should log and return false when non string value inputs are passed' do
      expect(Optimizely::Helpers::Validator.inputs_valid?({experiment_key: nil}, spy_logger, Logger::ERROR)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?({experiment_key: []}, spy_logger, Logger::ERROR)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?({experiment_key: {}}, spy_logger, Logger::ERROR)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?({experiment_key: 2}, spy_logger, Logger::ERROR)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?({experiment_key: 2.0}, spy_logger, Logger::ERROR)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?({experiment_key: true}, spy_logger, Logger::ERROR)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?({experiment_key: false}, spy_logger, Logger::ERROR)).to eq(false)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Experiment key is invalid').exactly(7).times
    end

    it 'should log and return false when multiple non string value inputs are passed' do
      expect(Optimizely::Helpers::Validator.inputs_valid?({variable_key: nil, experiment_key: true}, spy_logger, Logger::ERROR)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?({variable_key: [], variation_key: 2.0}, spy_logger, Logger::ERROR)).to eq(false)
      expect(spy_logger).to have_received(:log).twice.with(Logger::ERROR, 'Variable key is invalid')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Experiment key is invalid')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Variation key is invalid')
    end

    it 'should return true when valid input values are passed' do
      expect(Optimizely::Helpers::Validator.inputs_valid?({experiment_key: '2'}, spy_logger, Logger::ERROR)).to eq(true)
      expect(Optimizely::Helpers::Validator.inputs_valid?({
                                                            variable_key: 'test_variable',
                                                            experiment_key: 'test_experiment',
                                                            variation_key: 'test_variation'
                                                          }, spy_logger, Logger::ERROR)).to eq(true)
    end

    it 'should not log when logger or level are nil' do
      expect(Optimizely::Helpers::Validator.inputs_valid?({variable_key: nil}, nil, Logger::ERROR)).to eq(false)
      expect(Optimizely::Helpers::Validator.inputs_valid?({variable_key: nil}, spy_logger, nil)).to eq(false)
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, 'Variable key is invalid')
    end

    it 'should return nil when user is in no variation' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event)
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(nil)

      expect(project_instance.activate('test_experiment', 'test_user')).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Not activating user 'test_user'.")
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
    end

    it 'should log and send activate notification when an impression event is dispatched' do
      params = @expected_activate_params
      variation_to_return = project_instance.config.get_variation_from_id('test_experiment', '111128')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.config).to receive(:get_audience_ids_for_experiment)
        .with('test_experiment')
        .and_return([])
      experiment = project_instance.config.get_experiment_from_key('test_experiment')
      expect(project_instance.notification_center).to receive(:send_notifications).with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
        experiment, 'test_user', nil, variation_to_return,
        instance_of(Optimizely::Event)
      )
      project_instance.activate('test_experiment', 'test_user')

      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, include('Dispatching impression event to' \
                                                                                " URL #{impression_log_url} with params #{params}"))
    end

    it 'should log when an exception has occurred during dispatching the impression event' do
      variation_to_return = project_instance.config.get_variation_from_id('test_experiment', '111128')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(any_args).and_raise(RuntimeError)
      project_instance.activate('test_experiment', 'test_user')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Unable to dispatch impression event. Error: RuntimeError')
    end

    it 'should raise an exception when called with invalid attributes' do
      expect { project_instance.activate('test_experiment', 'test_user', 'invalid') }
        .to raise_error(Optimizely::InvalidAttributeFormatError)
    end

    it 'should override the audience check if the user is whitelisted to a specific variation' do
      params = @expected_activate_params
      params[:visitors][0][:visitor_id] = 'forced_audience_user'
      params[:visitors][0][:attributes].unshift(entity_id: '111094',
                                                key: 'browser_type',
                                                type: 'custom',
                                                value: 'wrong_browser')
      params[:visitors][0][:snapshots][0][:decisions] = [{
        campaign_id: '3',
        experiment_id: '122227',
        variation_id: '122229'
      }]
      params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '3'

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(Optimizely::Audience).to receive(:user_in_experiment?)

      expect(project_instance.activate('test_experiment_with_audience', 'forced_audience_user', 'browser_type' => 'wrong_browser'))
        .to eq('variation_with_audience')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
      expect(Optimizely::Audience).to_not have_received(:user_in_experiment?)
    end

    it 'should log an error when called with an invalid Project object' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }
      expect(logger).to receive(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(logger).to receive(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting activate.')

      invalid_project = Optimizely::Project.new('invalid')
      invalid_project.activate('test_exp', 'test_user')
    end
  end

  describe '#track' do
    before(:example) do
      allow(Time).to receive(:now).and_return(time_now)
      allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')

      @expected_track_event_params = {
        account_id: '12001',
        project_id: '111001',
        visitors: [{
          attributes: [{
            entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
            key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
            type: 'custom',
            value: true
          }],
          snapshots: [{
            events: [{
              entity_id: '111095',
              timestamp: (time_now.to_f * 1000).to_i,
              uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
              key: 'test_event'
            }]
          }],
          visitor_id: 'test_user'
        }],
        anonymize_ip: false,
        revision: '42',
        client_name: Optimizely::CLIENT_ENGINE,
        enrich_decisions: true,
        client_version: Optimizely::VERSION
      }
    end

    it 'should return nil when user_id is nil' do
      expect(project_instance.track('test_event', nil, nil, 'revenue' => 42)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'User ID is invalid')
    end

    it 'should call inputs_valid? with the proper arguments in track' do
      expect(Optimizely::Helpers::Validator).to receive(:inputs_valid?).with(
        {
          event_key: 'test_event',
          user_id: 'test_user'
        }, spy_logger, Logger::ERROR
      )
      project_instance.track('test_event', 'test_user')
    end

    it 'should log and return nil when user ID is non string' do
      expect(project_instance.track('test_event', nil)).to eq(nil)
      expect(project_instance.track('test_event', 5)).to eq(nil)
      expect(project_instance.track('test_event', 5.5)).to eq(nil)
      expect(project_instance.track('test_event', true)).to eq(nil)
      expect(project_instance.track('test_event', {})).to eq(nil)
      expect(project_instance.track('test_event', [])).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'User ID is invalid').exactly(6).times
    end

    it 'should properly track an event by calling dispatch_event with right params' do
      params = @expected_track_event_params

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should properly track an event by calling dispatch_event with right params after forced variation' do
      project_instance.config.set_forced_variation('test_experiment', 'test_user', 'variation')
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, @expected_track_event_params, post_headers)).once
    end

    it 'should properly track an event with tags even when the project does not have a custom logger' do
      project_instance = Optimizely::Project.new(config_body_JSON)

      params = @expected_track_event_params
      params[:visitors][0][:snapshots][0][:events][0][:tags] = {revenue: 42}

      project_instance.config.set_forced_variation('test_experiment', 'test_user', 'variation')
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user', nil, revenue: 42)
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should log a message if an exception has occurred during dispatching of the event' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(any_args).and_raise(RuntimeError)
      project_instance.track('test_event', 'test_user')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Unable to dispatch conversion event. Error: RuntimeError')
    end

    it 'should send track notification and properly track an event by calling dispatch_event with right params with revenue provided' do
      params = @expected_track_event_params
      params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 42,
                                                             tags: {'revenue' => 42})
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      conversion_event = Optimizely::Event.new(:post, conversion_log_url, params, post_headers)
      expect(project_instance.notification_center).to receive(:send_notifications)
        .with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK],
          'test_event', 'test_user', nil, {'revenue' => 42}, conversion_event
        ).once
      project_instance.track('test_event', 'test_user', nil, 'revenue' => 42)
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should properly track an event by calling dispatch_event with right params with attributes provided' do
      params = @expected_track_event_params
      params[:visitors][0][:attributes].unshift(
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'firefox'
      )
      params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '111097'
      params[:visitors][0][:snapshots][0][:events][0][:key] = 'test_event_with_audience'

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event_with_audience', 'test_user', 'browser_type' => 'firefox')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    describe '.typed audiences' do
      before(:example) do
        @project_typed_audience_instance = Optimizely::Project.new(JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES), nil, spy_logger, error_handler)
        @expected_event_params = {
          account_id: '4879520872',
          project_id: '11624721371',
          visitors: [
            {
              attributes: [
                {
                  entity_id: '594015',
                  key: 'house',
                  type: 'custom',
                  value: 'Welcome to Slytherin!'
                }, {
                  entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
                  key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
                  type: 'custom',
                  value: false
                }
              ],
              snapshots: [{
                events: [{
                  entity_id: '594089',
                  timestamp: (time_now.to_f * 1000).to_i,
                  uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
                  key: 'item_bought'
                }]
              }],
              visitor_id: 'test_user'
            }
          ],
          anonymize_ip: false,
          revision: '3',
          client_name: Optimizely::CLIENT_ENGINE,
          enrich_decisions: true,
          client_version: Optimizely::VERSION
        }
      end

      it 'should call dispatch_event with right params when attributes are provided' do
        # Should be included via substring match string audience with id '3988293898'
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        @project_typed_audience_instance.track('item_bought', 'test_user', 'house' => 'Welcome to Slytherin!')
        expect(@project_typed_audience_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, @expected_event_params, post_headers)).once
      end

      it 'should call dispatch_event even if typed audience conditions do not match' do
        params = @expected_event_params
        params[:visitors][0][:attributes][0][:value] = 'Welcome to Hufflepuff!'
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        @project_typed_audience_instance.track('item_bought', 'test_user', 'house' => 'Welcome to Hufflepuff!')
        expect(@project_typed_audience_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
      end

      it 'should call dispatch_event with right params when complex audience match' do
        # Should be included via exact match string audience with id '3468206642', and
        # exact match boolean audience with id '3468206643'
        params = @expected_event_params
        params[:visitors][0][:attributes] = [
          {
            entity_id: '594015',
            key: 'house',
            type: 'custom',
            value: 'Gryffindor'
          }, {
            entity_id: '594017',
            key: 'should_do_it',
            type: 'custom',
            value: true
          }, {
            entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
            key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
            type: 'custom',
            value: false
          }
        ]
        user_attributes = {'house' => 'Gryffindor', 'should_do_it' => true}
        params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '594090'
        params[:visitors][0][:snapshots][0][:events][0][:key] = 'user_signed_up'
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        @project_typed_audience_instance.track('user_signed_up', 'test_user', user_attributes)
        expect(@project_typed_audience_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
      end
    end

    it 'should call dispatch_event when tracking an event even if audience conditions do not match' do
      params = @expected_track_event_params
      params[:visitors][0][:attributes].unshift(
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'cyberdog'
      )
      params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '111097'
      params[:visitors][0][:snapshots][0][:events][0][:key] = 'test_event_with_audience'

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event_with_audience', 'test_user', 'browser_type' => 'cyberdog')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should call dispatch_event when tracking an event even if experiment is not running' do
      params = @expected_track_event_params
      params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '111098'
      params[:visitors][0][:snapshots][0][:events][0][:key] = 'test_event_not_running'
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event_not_running', 'test_user')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should log when a conversion event is dispatched' do
      params = @expected_track_event_params
      params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 42,
                                                             tags: {'revenue' => 42})

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user', nil, 'revenue' => 42)
      expect(spy_logger).to have_received(:log).with(Logger::INFO, include('Dispatching conversion event to' \
                                                                                " URL #{conversion_log_url} with params #{params}"))
    end

    it 'should raise an exception when called with attributes in an invalid format' do
      expect { project_instance.track('test_event', 'test_user', 'invalid') }
        .to raise_error(Optimizely::InvalidAttributeFormatError)
    end

    it 'should return false when called with attributes in an invalid format' do
      expect(project_instance.error_handler).to receive(:handle_error).with(any_args).once.and_return(nil)
      project_instance.track('test_event', 'test_user', 'invalid')
    end

    it 'should raise an exception when called with event tags in an invalid format' do
      expect { project_instance.track('test_event', 'test_user', nil, 'invalid_tags') }
        .to raise_error(Optimizely::InvalidEventTagFormatError)
      expect { project_instance.track('test_event', 'test_user', nil, 42) }
        .to raise_error(Optimizely::InvalidEventTagFormatError)
      expect(spy_logger).to have_received(:log).twice.with(Logger::ERROR, 'Provided event tags are in an invalid format.')
    end

    it 'should return false when called with event tags in an invalid format' do
      expect(project_instance.error_handler).to receive(:handle_error).with(any_args).once.and_return(nil)
      project_instance.track('test_event', 'test_user', nil, 'invalid_tags')
    end

    it 'should return nil and not call dispatch_event for an invalid event' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event)

      expect { project_instance.track('invalid_event', 'test_user') }.to raise_error(Optimizely::InvalidEventError)
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
    end

    it 'should return nil and does not call dispatch_event if event is not in datafile' do
      allow(project_instance.config).to receive(:get_event_from_key).with(any_args).and_return(nil)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event)

      expect(project_instance.track('invalid_event', 'test_user')).to eq(nil)
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
      expect(spy_logger).to have_received(:log).with(Logger::INFO, "Not tracking user 'test_user' for event 'invalid_event'.")
    end

    it 'should override the audience check if the user is whitelisted to a specific variation' do
      params = @expected_track_event_params
      params[:visitors][0][:visitor_id] = 'forced_audience_user'
      params[:visitors][0][:attributes].unshift(
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'wrong_browser'
      )
      params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '111097'
      params[:visitors][0][:snapshots][0][:events][0][:key] = 'test_event_with_audience'

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(Optimizely::Audience).to receive(:user_in_experiment?)

      project_instance.track('test_event_with_audience', 'forced_audience_user', 'browser_type' => 'wrong_browser')
      expect(Optimizely::Audience).to_not have_received(:user_in_experiment?)
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should log an error when called with an invalid Project object' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }
      expect(logger).to receive(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(logger).to receive(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting track.')

      invalid_project = Optimizely::Project.new('invalid')
      invalid_project.track('test_event', 'test_user')
    end
  end

  describe '#get_variation' do
    it 'should call inputs_valid? with the proper arguments in get_variation' do
      expect(Optimizely::Helpers::Validator).to receive(:inputs_valid?).with(
        {
          experiment_key: 'test_experiment_with_audience',
          user_id: 'test_user'
        }, spy_logger, Logger::ERROR
      )
      project_instance.get_variation('test_experiment_with_audience', 'test_user', nil)
    end

    it 'should log and return nil when user ID is non string' do
      expect(project_instance.get_variation('test_experiment_with_audience', nil)).to eq(nil)
      expect(project_instance.get_variation('test_experiment_with_audience', 5)).to eq(nil)
      expect(project_instance.get_variation('test_experiment_with_audience', 5.5)).to eq(nil)
      expect(project_instance.get_variation('test_experiment_with_audience', true)).to eq(nil)
      expect(project_instance.get_variation('test_experiment_with_audience', {})).to eq(nil)
      expect(project_instance.get_variation('test_experiment_with_audience', [])).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'User ID is invalid').exactly(6).times
    end

    it 'should have get_variation return expected variation when there are no audiences' do
      expect(project_instance.get_variation('test_experiment', 'test_user'))
        .to eq(config_body['experiments'][0]['variations'][0]['key'])
    end

    it 'should have get_variation return expected variation with bucketing id attribute when there are no audiences' do
      expect(project_instance.get_variation('test_experiment', 'test_user', nil))
        .to eq(config_body['experiments'][0]['variations'][0]['key'])
    end

    it 'should have get_variation return expected variation when audience conditions match' do
      user_attributes = {'browser_type' => 'firefox'}
      expect(project_instance.get_variation('test_experiment_with_audience', 'test_user', user_attributes))
        .to eq('control_with_audience')
    end

    it 'should have get_variation return expected variation with bucketing id attribute when audience conditions match' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 'pid'
      }
      expect(project_instance.get_variation('test_experiment_with_audience', 'test_user', user_attributes))
        .to eq('control_with_audience')
    end

    it 'should have get_variation return nil when attributes are invalid' do
      allow(project_instance).to receive(:attributes_valid?).and_return(false)
      expect(project_instance.get_variation('test_experiment_with_audience', 'test_user', 'invalid')).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Not activating user 'test_user.")
    end

    it 'should have get_variation return nil when audience conditions do not match' do
      user_attributes = {'browser_type' => 'chrome'}
      expect(project_instance.get_variation('test_experiment_with_audience', 'test_user', user_attributes))
        .to eq(nil)
    end

    it 'should have get_variation return nil with bucketing id attribute when audience conditions do not match' do
      user_attributes = {'browser_type' => 'chrome',
                         Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 'pid'}
      expect(project_instance.get_variation('test_experiment_with_audience', 'test_user', user_attributes))
        .to eq(nil)
    end

    it 'should have get_variation return nil when experiment is not Running' do
      expect(project_instance.get_variation('test_experiment_not_started', 'test_user')).to eq(nil)
    end

    it 'should have get_variation return nil with bucketing id attribute when experiment is not Running' do
      user_attributes = {
        'browser_type' => 'firefox',
        Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'] => 'pid'
      }
      expect(project_instance.get_variation('test_experiment_not_started', 'test_user', user_attributes)).to eq(nil)
    end

    it 'should raise an exception when called with invalid attributes' do
      expect { project_instance.get_variation('test_experiment', 'test_user', 'invalid') }
        .to raise_error(Optimizely::InvalidAttributeFormatError)
    end

    it 'should override the audience check if the user is whitelisted to a specific variation' do
      allow(Optimizely::Audience).to receive(:user_in_experiment?)

      expect(project_instance.get_variation('test_experiment_with_audience', 'forced_audience_user', 'browser_type' => 'wrong_browser'))
        .to eq('variation_with_audience')
      expect(Optimizely::Audience).to_not have_received(:user_in_experiment?)
    end

    it 'should log an error when called with an invalid Project object' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }
      expect(logger).to receive(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(logger).to receive(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting get_variation.')

      invalid_project = Optimizely::Project.new('invalid')
      invalid_project.get_variation('test_exp', 'test_user')
    end
  end

  describe '#is_feature_enabled' do
    before(:example) do
      allow(Time).to receive(:now).and_return(time_now)
      allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')

      @expected_bucketed_params = {
        account_id: '12001',
        project_id: '111001',
        visitors: [{
          attributes: [{
            entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
            key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
            type: 'custom',
            value: true
          }],
          snapshots: [{
            decisions: [{
              campaign_id: '4',
              experiment_id: '122230',
              variation_id: '122231'
            }],
            events: [{
              entity_id: '4',
              timestamp: (time_now.to_f * 1000).to_i,
              key: 'campaign_activated',
              uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c'
            }]
          }],
          visitor_id: 'test_user'
        }],
        anonymize_ip: false,
        revision: '42',
        client_name: Optimizely::CLIENT_ENGINE,
        enrich_decisions: true,
        client_version: Optimizely::VERSION
      }
    end

    it 'should return false when called with invalid project config' do
      invalid_project = Optimizely::Project.new('invalid', nil, spy_logger)
      expect(invalid_project.is_feature_enabled('totally_invalid_feature_key', 'test_user')).to be false
    end

    it 'should return false when the feature flag key is nil' do
      expect(project_instance.is_feature_enabled(nil, 'test_user')).to be false
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Feature flag key is invalid')
    end

    it 'should return false when the feature flag key is invalid' do
      expect(project_instance.is_feature_enabled('totally_invalid_feature_key', 'test_user')).to be false
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Feature flag key 'totally_invalid_feature_key' is not in datafile.")
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "No feature flag was found for key 'totally_invalid_feature_key'.")
    end

    it 'should call inputs_valid? with the proper arguments in is_feature_enabled' do
      expect(Optimizely::Helpers::Validator).to receive(:inputs_valid?).with(
        {
          feature_flag_key: 'multi_variate_feature',
          user_id: 'test_user'
        }, spy_logger, Logger::ERROR
      )
      project_instance.is_feature_enabled('multi_variate_feature', 'test_user')
    end

    it 'should log and return false when user ID is non string' do
      expect(project_instance.is_feature_enabled('multi_variate_feature', nil)).to be(false)
      expect(project_instance.is_feature_enabled('multi_variate_feature', 5)).to be(false)
      expect(project_instance.is_feature_enabled('multi_variate_feature', 5.5)).to be(false)
      expect(project_instance.is_feature_enabled('multi_variate_feature', true)).to be(false)
      expect(project_instance.is_feature_enabled('multi_variate_feature', {})).to be(false)
      expect(project_instance.is_feature_enabled('multi_variate_feature', [])).to be(false)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'User ID is invalid').exactly(6).times
    end

    it 'should return false when attributes are invalid' do
      expect(Optimizely::Helpers::Validator).to receive(:attributes_valid?).once.with('invalid')
      expect(error_handler).to receive(:handle_error).once.with(Optimizely::InvalidAttributeFormatError)
      expect(project_instance.is_feature_enabled('multi_variate_feature', 'test_user', 'invalid')).to be false
    end

    it 'should log and raise an exception when called with attributes in an invalid format' do
      expect_any_instance_of(Optimizely::RaiseErrorHandler).to receive(:handle_error).once.with(Optimizely::InvalidAttributeFormatError)
      expect(project_instance.is_feature_enabled('multi_variate_feature', 'test_user', 'invalid_attributes')).to be false
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided attributes are in an invalid format.')
    end

    it 'should return false when the user is not bucketed into any variation' do
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(nil)

      expect(project_instance.is_feature_enabled('multi_variate_feature', 'test_user')).to be(false)
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'multi_variate_feature' is not enabled for user 'test_user'.")
    end

    it 'should return true but not send an impression if the user is not bucketed into a feature experiment' do
      experiment_to_return = config_body['rollouts'][0]['experiments'][0]
      variation_to_return = experiment_to_return['variations'][0]

      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCE_ROLLOUT
      )
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user')).to be true
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, "The user 'test_user' is not being experimented on in feature 'boolean_single_variable_feature'.")
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'boolean_single_variable_feature' is enabled for user 'test_user'.")
    end

    it 'should return false, if the user is bucketed into a feature rollout but the featureEnabled property is false' do
      experiment_to_return = config_body['rollouts'][0]['experiments'][1]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCE_ROLLOUT
      )
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
      expect(variation_to_return['featureEnabled']).to be false

      expect(project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user')).to be false
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'boolean_single_variable_feature' is not enabled for user 'test_user'.")
    end

    it 'should return true, if the user is bucketed into a feature rollout when featureEnabled property is true' do
      experiment_to_return = config_body['rollouts'][0]['experiments'][0]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCE_ROLLOUT
      )
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
      expect(variation_to_return['featureEnabled']).to be true

      expect(project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user')).to be true
      expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, "The user 'test_user' is not being experimented on in feature 'boolean_single_variable_feature'.")
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'boolean_single_variable_feature' is enabled for user 'test_user'.")
    end

    describe '.typed audiences' do
      before(:example) do
        @project_typed_audience_instance = Optimizely::Project.new(JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES), nil, spy_logger, error_handler)
      end

      it 'should return true for feature rollout when typed audience matched' do
        # Should be included via exists match audience with id '3988293899'
        expect(@project_typed_audience_instance.is_feature_enabled(
                 'feat', 'test_user',
                 'favorite_ice_cream' => 'chocolate'
               )).to be true

        # Should be included via less-than match audience with id '3468206644'
        expect(@project_typed_audience_instance.is_feature_enabled(
                 'feat', 'test_user',
                 'lasers' => -3
               )).to be true

        expect(spy_logger).to have_received(:log).twice.with(Logger::DEBUG, "The user 'test_user' is not being experimented on in feature 'feat'.")
        expect(spy_logger).to have_received(:log).twice.with(Logger::INFO, "Feature 'feat' is enabled for user 'test_user'.")
      end

      it 'should return false for feature rollout when typed audience mismatch' do
        expect(@project_typed_audience_instance.is_feature_enabled('feat', 'test_user', {})).to be false

        expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "User 'test_user' is not bucketed into a rollout for feature flag 'feat'.")
        expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'feat' is not enabled for user 'test_user'.")
      end

      it 'should return true for feature rollout with complex audience match' do
        # Should be included via substring match string audience with id '3988293898', and
        # exists audience with id '3988293899'
        user_attributes = {'house' => '...Slytherinnn...sss.', 'favorite_ice_cream' => 'matcha'}

        expect(@project_typed_audience_instance.is_feature_enabled(
                 'feat2', 'test_user', user_attributes
               )).to be true

        expect(spy_logger).to have_received(:log).once.with(Logger::DEBUG, "The user 'test_user' is not being experimented on in feature 'feat2'.")
        expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'feat2' is enabled for user 'test_user'.")
      end

      it 'should return false for feature rollout with complex audience mismatch' do
        # Should be excluded - substring match string audience with id '3988293898' does not match,
        # and no audience in the other branch of the 'and' matches either
        expect(@project_typed_audience_instance.is_feature_enabled('feat2', 'test_user', 'house' => 'Lannister')).to be false

        expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "User 'test_user' is not bucketed into a rollout for feature flag 'feat2'.")
        expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'feat2' is not enabled for user 'test_user'.")
      end
    end

    it 'should return true, send activate notification and an impression if the user is bucketed into a feature experiment' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      experiment_to_return = config_body['experiments'][3]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCE_EXPERIMENT
      )

      expect(project_instance.notification_center).to receive(:send_notifications)
        .with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
          experiment_to_return, 'test_user', nil, variation_to_return,
          instance_of(Optimizely::Event)
        ).ordered

      expect(project_instance.notification_center).to receive(:send_notifications).ordered

      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expected_params = @expected_bucketed_params

      expect(project_instance.is_feature_enabled('multi_variate_feature', 'test_user')).to be true
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Dispatching impression event to URL https://logx.optimizely.com/v1/events with params #{expected_params}.")
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'multi_variate_feature' is enabled for user 'test_user'.")
    end

    it 'should return false and send impression if the user is bucketed into a feature experiment but the featureEnabled property is false' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      experiment_to_return = config_body['experiments'][3]
      variation_to_return = experiment_to_return['variations'][1]
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCE_EXPERIMENT
      )
      expect(variation_to_return['featureEnabled']).to be false
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.is_feature_enabled('multi_variate_feature', 'test_user')).to be false
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(instance_of(Optimizely::Event)).once
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'multi_variate_feature' is not enabled for user 'test_user'.")
    end

    describe '.decision listener' do
      it 'should call decision listener when user is bucketed into a feature experiment with featureEnabled property is true' do
        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][0]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCE_EXPERIMENT
        )

        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

        expect(project_instance.notification_center).to receive(:send_notifications).ordered

        # DECISION listener called when the user is in experiment with variation feature on.
        expect(variation_to_return['featureEnabled']).to be true
        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', nil,
          decision_info: {
            feature_enabled: true,
            feature_key: 'multi_variate_feature',
            source: 'EXPERIMENT',
            source_experiment_key: 'test_experiment_multivariate',
            source_variation_key: 'Fred'
          }
        ).ordered

        project_instance.is_feature_enabled('multi_variate_feature', 'test_user')
      end

      it 'should call decision listener when user is bucketed into a feature experiment with featureEnabled property is false' do
        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][1]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCE_EXPERIMENT
        )

        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

        expect(project_instance.notification_center).to receive(:send_notifications).ordered

        # DECISION listener called when the user is in experiment with variation feature off.
        expect(variation_to_return['featureEnabled']).to be false
        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'chrome'},
          decision_info: {
            feature_enabled: false,
            feature_key: 'multi_variate_feature',
            source: 'EXPERIMENT',
            source_experiment_key: 'test_experiment_multivariate',
            source_variation_key: 'Feorge'
          }
        )

        project_instance.is_feature_enabled('multi_variate_feature', 'test_user', 'browser_type' => 'chrome')
      end

      it 'should call decision listener when user is bucketed into rollout with featureEnabled property is true' do
        experiment_to_return = config_body['rollouts'][0]['experiments'][0]
        variation_to_return = experiment_to_return['variations'][0]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCE_ROLLOUT
        )
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

        # DECISION listener called when the user is in rollout with variation feature true.
        expect(variation_to_return['featureEnabled']).to be true
        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          decision_info: {
            feature_enabled: true,
            feature_key: 'boolean_single_variable_feature',
            source: 'ROLLOUT',
            source_experiment_key: nil,
            source_variation_key: nil
          }
        )

        project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user', 'browser_type' => 'firefox')
      end

      it 'should call decision listener when user is bucketed into rollout with featureEnabled property is false' do
        experiment_to_return = config_body['rollouts'][0]['experiments'][1]
        variation_to_return = experiment_to_return['variations'][0]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCE_ROLLOUT
        )
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

        # DECISION listener called when the user is in rollout with variation feature off.
        expect(variation_to_return['featureEnabled']).to be false
        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', nil,
          decision_info: {
            feature_enabled: false,
            feature_key: 'boolean_single_variable_feature',
            source: 'ROLLOUT',
            source_experiment_key: nil,
            source_variation_key: nil
          }
        )

        project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user')
      end

      it 'call decision listener when the user is not bucketed into any experiment or rollout' do
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(nil)

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          decision_info: {
            feature_enabled: false,
            feature_key: 'multi_variate_feature',
            source: 'ROLLOUT',
            source_experiment_key: nil,
            source_variation_key: nil
          }
        )

        project_instance.is_feature_enabled('multi_variate_feature', 'test_user', 'browser_type' => 'firefox')
      end
    end
  end

  describe '#get_enabled_features' do
    it 'should return empty when called with invalid project config' do
      invalid_project = Optimizely::Project.new('invalid', nil, spy_logger)
      expect(invalid_project.get_enabled_features('test_user')).to be_empty
    end

    it 'should call inputs_valid? with the proper arguments in get_enabled_features' do
      expect(Optimizely::Helpers::Validator).to receive(:inputs_valid?).with(
        {
          user_id: 'test_user'
        }, spy_logger, Logger::ERROR
      )
      project_instance.get_enabled_features('test_user')
    end

    it 'should return empty when no feature flag is enabled' do
      allow(project_instance).to receive(:is_feature_enabled).and_return(false)
      expect(project_instance.get_enabled_features('test_user')).to be_empty
    end

    it 'should log and return empty when user ID is non string' do
      expect(project_instance.get_enabled_features(nil)).to be_empty
      expect(project_instance.get_enabled_features(5)).to be_empty
      expect(project_instance.get_enabled_features(5.5)).to be_empty
      expect(project_instance.get_enabled_features(true)).to be_empty
      expect(project_instance.get_enabled_features({})).to be_empty
      expect(project_instance.get_enabled_features([])).to be_empty
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'User ID is invalid').exactly(6).times
    end

    it 'should return empty when attributes are invalid' do
      expect(Optimizely::Helpers::Validator).to receive(:attributes_valid?).once.with('invalid')
      expect(error_handler).to receive(:handle_error).once.with(Optimizely::InvalidAttributeFormatError)
      expect(project_instance.get_enabled_features('test_user', 'invalid')).to be_empty
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided attributes are in an invalid format.')
    end

    it 'should log and raise an exception when called with attributes in an invalid format' do
      expect_any_instance_of(Optimizely::RaiseErrorHandler).to receive(:handle_error).once.with(Optimizely::InvalidAttributeFormatError)
      expect(project_instance.get_enabled_features('test_user', 'invalid_attributes')).to be_empty
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided attributes are in an invalid format.')
    end

    it 'should return only enabled feature flags keys' do
      # Sets all feature-flags keys with randomly assigned status
      features_keys = project_instance.config.feature_flags.map do |item|
        {key: (item['key']).to_s, value: [true, false].sample} # '[true, false].sample' generates random boolean
      end

      enabled_features = features_keys.map { |x| x[:key] if x[:value] == true }.compact
      disabled_features = features_keys.map { |x| x[:key] if x[:value] == false }.compact

      features_keys.each do |feature|
        allow(project_instance).to receive(:is_feature_enabled).with(feature[:key], 'test_user', 'browser_type' => 'chrome').and_return(feature[:value])
      end

      # Checks enabled features are returned
      expect(project_instance.get_enabled_features('test_user', 'browser_type' => 'chrome')).to include(*enabled_features)
      expect(project_instance.get_enabled_features('test_user', 'browser_type' => 'chrome').length).to eq(enabled_features.length)

      # Checks prevented features should not return
      expect(project_instance.get_enabled_features('test_user', 'browser_type' => 'chrome')).not_to include(*disabled_features)
    end

    describe '.decision listener' do
      it 'should call decision listener multiple times for each feature and feature enabled value is false in all cases.' do
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(nil)

        expect(project_instance.notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION], any_args
        ).exactly(8).times

        expect(project_instance.is_feature_enabled(any_args, 'test_user', 'browser_type' => 'chrome')).to be false
        expect(project_instance.get_enabled_features('test_user', 'browser_type' => 'chrome')).to be_empty
      end

      it 'should return enabled features and call decision listener for all features' do
        enabled_features = %w[boolean_feature integer_single_variable_feature boolean_single_variable_feature mutex_group_feature]
        experiment_to_return = config_body['rollouts'][0]['experiments'][0]
        variation_to_return = experiment_to_return['variations'][0]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCE_ROLLOUT
        )

        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(
          decision_to_return, nil, decision_to_return, decision_to_return, nil, nil, decision_to_return, nil
        )

        expect(project_instance.notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION], any_args
        ).exactly(project_instance.config.feature_flags.length).times

        expect(project_instance.get_enabled_features('test_user', 'browser_type' => 'firefox')).to eq(enabled_features)
      end
    end
  end

  describe '#get_feature_variable_string' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should return nil when called with invalid project config' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }
      invalid_project = Optimizely::Project.new('invalid', nil, spy_logger)
      expect(invalid_project.get_feature_variable_string('string_single_variable_feature', 'string_variable', user_id, user_attributes))
        .to eq(nil)
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting get_feature_variable_string.')
    end

    describe 'when the feature flag is enabled for the user' do
      describe 'and a variable usage instance is not found' do
        it 'should return the default variable value' do
          variation_to_return = project_instance.config.rollout_id_map['166661']['experiments'][0]['variations'][0]
          decision_to_return = {
            'experiment' => nil,
            'variation' => variation_to_return
          }
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.get_feature_variable_string('string_single_variable_feature', 'string_variable', user_id, user_attributes))
            .to eq('wingardium leviosa')
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::DEBUG,
                                                     "Variable 'string_variable' is not used in variation '177775'. Returning the default variable value 'wingardium leviosa'."
                                                   )
        end
      end

      describe 'and a variable usage instance is found' do
        describe 'and the variable type boolean is not a string' do
          it 'should log a warning' do
            variation_to_return = project_instance.config.rollout_id_map['166660']['experiments'][0]['variations'][0]
            decision_to_return = {
              'experiment' => nil,
              'variation' => variation_to_return
            }
            allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

            expect(project_instance.get_feature_variable_string('boolean_single_variable_feature', 'boolean_variable', user_id, user_attributes))
              .to eq(nil)
            expect(spy_logger).to have_received(:log).once
                                                     .with(
                                                       Logger::WARN,
                                                       "Requested variable as type 'string' but variable 'boolean_variable' is of type 'boolean'."
                                                     )
          end
        end

        describe 'and the variable type integer is not a string' do
          it 'should log a warning' do
            integer_feature = project_instance.config.feature_flag_key_map['integer_single_variable_feature']
            experiment_to_return = project_instance.config.experiment_id_map[integer_feature['experimentIds'][0]]
            variation_to_return = experiment_to_return['variations'][0]
            decision_to_return = {
              'experiment' => experiment_to_return,
              'variation' => variation_to_return
            }
            allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

            expect(project_instance.get_feature_variable_string('integer_single_variable_feature', 'integer_variable', user_id, user_attributes))
              .to eq(nil)
            expect(spy_logger).to have_received(:log).once
                                                     .with(
                                                       Logger::WARN,
                                                       "Requested variable as type 'string' but variable 'integer_variable' is of type 'integer'."
                                                     )
          end
        end

        it 'should return the variable value for the variation for the user is bucketed into' do
          experiment_to_return = project_instance.config.experiment_key_map['test_experiment_with_feature_rollout']
          variation_to_return = experiment_to_return['variations'][0]
          decision_to_return = {
            'experiment' => experiment_to_return,
            'variation' => variation_to_return
          }
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.get_feature_variable_string('string_single_variable_feature', 'string_variable', user_id, user_attributes))
            .to eq('cta_1')

          expect(spy_logger).to have_received(:log).once
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value 'cta_1' for variable 'string_variable' of feature flag 'string_single_variable_feature'."
                                                   )
        end
      end
    end

    describe 'when the feature flag is not enabled for the user' do
      it 'should return the default variable value' do
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(nil)

        expect(project_instance.get_feature_variable_string('string_single_variable_feature', 'string_variable', user_id, user_attributes))
          .to eq('wingardium leviosa')
        expect(spy_logger).to have_received(:log).once
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::INFO,
                                                   "User 'test_user' was not bucketed into any variation for feature flag 'string_single_variable_feature'. Returning the default variable value 'wingardium leviosa'."
                                                 )
      end
    end

    describe 'when the specified feature flag is invalid' do
      it 'should log an error message and return nil' do
        expect(project_instance.get_feature_variable_string('totally_invalid_feature_key', 'string_variable', user_id, user_attributes))
          .to eq(nil)
        expect(spy_logger).to have_received(:log).twice
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::ERROR,
                                                   "Feature flag key 'totally_invalid_feature_key' is not in datafile."
                                                 )
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::INFO,
                                                   "No feature flag was found for key 'totally_invalid_feature_key'."
                                                 )
      end
    end

    describe 'when the specified feature variable is invalid' do
      it 'should log an error message and return nil' do
        expect(project_instance.get_feature_variable_string('string_single_variable_feature', 'invalid_string_variable', user_id, user_attributes))
          .to eq(nil)
        expect(spy_logger).to have_received(:log).once
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::ERROR,
                                                   "No feature variable was found for key 'invalid_string_variable' in feature flag 'string_single_variable_feature'."
                                                 )
      end
    end
  end

  describe '#get_feature_variable_boolean' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should return nil when called with invalid project config' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }
      invalid_project = Optimizely::Project.new('invalid', nil, spy_logger)
      expect(invalid_project.get_feature_variable_boolean('boolean_single_variable_feature', 'boolean_variable', user_id, user_attributes))
        .to eq(nil)
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting get_feature_variable_boolean.')
    end

    it 'should return the variable value for the variation for the user is bucketed into' do
      boolean_feature = project_instance.config.feature_flag_key_map['boolean_single_variable_feature']
      rollout = project_instance.config.rollout_id_map[boolean_feature['rolloutId']]
      variation_to_return = rollout['experiments'][0]['variations'][0]
      decision_to_return = {
        'experiment' => nil,
        'variation' => variation_to_return
      }
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.get_feature_variable_boolean('boolean_single_variable_feature', 'boolean_variable', user_id, user_attributes))
        .to eq(true)

      expect(spy_logger).to have_received(:log).once
      expect(spy_logger).to have_received(:log).once
                                               .with(
                                                 Logger::INFO,
                                                 "Got variable value 'true' for variable 'boolean_variable' of feature flag 'boolean_single_variable_feature'."
                                               )
    end
  end

  describe '#get_feature_variable_double' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should return nil when called with invalid project config' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }
      invalid_project = Optimizely::Project.new('invalid', nil, spy_logger)
      expect(invalid_project.get_feature_variable_double('double_single_variable_feature', 'double_variable', user_id, user_attributes))
        .to eq(nil)
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting get_feature_variable_double.')
    end

    it 'should return the variable value for the variation for the user is bucketed into' do
      double_feature = project_instance.config.feature_flag_key_map['double_single_variable_feature']
      experiment_to_return = project_instance.config.experiment_id_map[double_feature['experimentIds'][0]]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = {
        'experiment' => experiment_to_return,
        'variation' => variation_to_return
      }

      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.get_feature_variable_double('double_single_variable_feature', 'double_variable', user_id, user_attributes))
        .to eq(42.42)

      expect(spy_logger).to have_received(:log).once
      expect(spy_logger).to have_received(:log).once
                                               .with(
                                                 Logger::INFO,
                                                 "Got variable value '42.42' for variable 'double_variable' of feature flag 'double_single_variable_feature'."
                                               )
    end
  end

  describe '#get_feature_variable_integer' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should return nil when called with invalid project config' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }
      invalid_project = Optimizely::Project.new('invalid', nil, spy_logger)
      expect(invalid_project.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', user_id, user_attributes))
        .to eq(nil)
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting get_feature_variable_integer.')
    end

    it 'should return the variable value for the variation for the user is bucketed into' do
      integer_feature = project_instance.config.feature_flag_key_map['integer_single_variable_feature']
      experiment_to_return = project_instance.config.experiment_id_map[integer_feature['experimentIds'][0]]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = {
        'experiment' => experiment_to_return,
        'variation' => variation_to_return
      }

      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', user_id, user_attributes))
        .to eq(42)

      expect(spy_logger).to have_received(:log).once
      expect(spy_logger).to have_received(:log).once
                                               .with(
                                                 Logger::INFO,
                                                 "Got variable value '42' for variable 'integer_variable' of feature flag 'integer_single_variable_feature'."
                                               )
    end
  end

  describe '#get_feature_variable_for_type with empty params' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should return nil if feature_flag_key is nil' do
      expect(project_instance.get_feature_variable_integer(nil, 'integer_variable', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Feature flag key is invalid')
    end

    it 'should return nil if variable_key is nil' do
      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', nil, user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Variable key is invalid')
    end

    it 'should call inputs_valid? with the proper arguments in get_feature_variable_for_type' do
      expect(Optimizely::Helpers::Validator).to receive(:inputs_valid?).with(
        {
          feature_flag_key: 'integer_single_variable_feature',
          variable_key: 'integer_variable',
          user_id: 'test_user',
          variable_type: 'integer'
        }, spy_logger, Logger::ERROR
      )
      project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', 'test_user', user_attributes)
    end

    it 'should log and return nil when user ID is non string' do
      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', nil)).to eq(nil)
      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', 5)).to eq(nil)
      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', 5.5)).to eq(nil)
      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', true)).to eq(nil)
      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', {})).to eq(nil)
      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', [])).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'User ID is invalid').exactly(6).times
    end

    describe '.typed audiences' do
      before(:example) do
        @project_typed_audience_instance = Optimizely::Project.new(JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES), nil, spy_logger, error_handler)
      end

      it 'should return variable value when typed audience match' do
        # Should be included in the feature test via greater-than match audience with id '3468206647'
        expect(@project_typed_audience_instance.get_feature_variable_string(
                 'feat_with_var',
                 'x', 'user1', 'lasers' => 71
               )).to eq('xyz')

        # Should be included in the feature test via exact match boolean audience with id '3468206643'
        expect(@project_typed_audience_instance.get_feature_variable_string(
                 'feat_with_var',
                 'x', 'user1', 'should_do_it' => true
               )).to eq('xyz')
      end

      it 'should return default_value when typed audience mismatch' do
        expect(@project_typed_audience_instance.get_feature_variable_string(
                 'feat_with_var',
                 'x', 'user1', 'lasers' => 50
               )).to eq('x')
      end

      it 'should return variable value with complex audience match' do
        # Should be included via exact match string audience with id '3468206642', and
        # greater than audience with id '3468206647'
        user_attributes = {'house' => 'Gryffindor', 'lasers' => 700}
        expect(@project_typed_audience_instance.get_feature_variable_integer(
                 'feat2_with_var',
                 'z', 'user1', user_attributes
               )).to eq(150)
      end

      it 'should return default value with complex audience mismatch' do
        # Should be excluded - no audiences match with no attributes
        expect(@project_typed_audience_instance.get_feature_variable_integer(
                 'feat2_with_var', 'z', 'user1', {}
               )).to eq(10)
      end
    end
  end

  describe '#get_feature_variable_for_type with invalid attributes' do
    it 'should return nil when attributes are invalid' do
      expect(Optimizely::Helpers::Validator).to receive(:attributes_valid?).once.with('invalid')
      expect(error_handler).to receive(:handle_error).once.with(Optimizely::InvalidAttributeFormatError)
      expect(project_instance.send(
               :get_feature_variable_for_type,
               'integer_single_variable_feature',
               'integer_variable',
               'integer',
               'test_user',
               'invalid'
             )).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided attributes are in an invalid format.')
    end

    it 'should log and raise an exception when called with attributes in an invalid format' do
      expect_any_instance_of(Optimizely::RaiseErrorHandler).to receive(:handle_error).once.with(Optimizely::InvalidAttributeFormatError)
      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', 'test_user', 'invalid_attributes')).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided attributes are in an invalid format.')
    end
  end

  describe 'when forced variation is used' do
    # setForcedVariation on a paused experiment and then call getVariation.
    it 'should return null when getVariation is called on a paused experiment after setForcedVariation' do
      project_instance.set_forced_variation('test_experiment_not_started', 'test_user', 'control_not_started')
      expect(project_instance.get_variation('test_experiment_not_started', 'test_user')). to eq(nil)
    end

    # setForcedVariation on a running experiment and then call getVariation.
    it 'should return expected variation id  when getVariation is called on a running experiment after setForcedVariation' do
      project_instance.set_forced_variation('test_experiment', 'test_user', 'variation')
      expect(project_instance.get_variation('test_experiment', 'test_user')). to eq('variation')
    end

    # setForcedVariation on a whitelisted user on the variation that they are not forced into and then call getVariation on the user.
    it 'should return expected forced variation id  when getVariation is called on a running experiment after setForcedVariation is called on a whitelisted user' do
      project_instance.set_forced_variation('test_experiment', 'forced_user1', 'variation')
      expect(project_instance.get_variation('test_experiment', 'forced_user1')). to eq('variation')
    end

    # setForcedVariation on a running experiment with a previously set variation (different from the one set by setForcedVariation) and then call getVariation.
    it 'should return latest set variation when different variations are set on the same experiment' do
      project_instance.set_forced_variation('test_experiment', 'test_user', 'control')
      project_instance.set_forced_variation('test_experiment', 'test_user', 'variation')
      expect(project_instance.get_variation('test_experiment', 'test_user')). to eq('variation')
    end

    # setForcedVariation on a running experiment with audience enabled and then call getVariation on that same experiment with invalid attributes.
    it 'should return nil when getVariation called on audience enabled running experiment with invalid attributes' do
      project_instance.set_forced_variation('test_experiment_with_audience', 'test_user', 'control_with_audience')
      expect { project_instance.get_variation('test_experiment_with_audience', 'test_user', 'invalid') }
        .to raise_error(Optimizely::InvalidAttributeFormatError)
    end

    # Adding this test case to cover this in code coverage. All test cases for getForceVariation are present in
    # project_config_spec.rb which test the get_force_variation method in project_config. The one in optimizely.rb
    # only calls the other one

    # getForceVariation on a running experiment after setforcevariation
    it 'should return expected variation id  when get_forced_variation is called on a running experiment after setForcedVariation' do
      project_instance.set_forced_variation('test_experiment', 'test_user', 'variation')
      expect(project_instance.get_forced_variation('test_experiment', 'test_user')). to eq('variation')
    end
  end
end
