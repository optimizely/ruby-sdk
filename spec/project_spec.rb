# frozen_string_literal: true

#
#    Copyright 2016-2020, 2022-2023, Optimizely and contributors
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
require 'optimizely/config_manager/http_project_config_manager'
require 'optimizely/event_dispatcher'
require 'optimizely/event/batch_event_processor'
require 'optimizely/exceptions'
require 'optimizely/helpers/validator'
require 'optimizely/helpers/sdk_settings'
require 'optimizely/optimizely_user_context'
require 'optimizely/version'

describe 'Optimizely' do
  # need different sdk_key for every instance, otherwise notification center callbacks get called for the wrong tests
  let!(:sdk_key) { SecureRandom.uuid }
  let(:config_body) do
    datafile = OptimizelySpec::VALID_CONFIG_BODY.dup
    datafile['sdkKey'] = sdk_key
    datafile
  end
  let(:config_body_JSON) { JSON.dump(config_body) }
  let(:config_body_invalid_JSON) { OptimizelySpec::INVALID_CONFIG_BODY_JSON }
  let(:config_body_integrations) do
    datafile = OptimizelySpec::CONFIG_DICT_WITH_INTEGRATIONS.dup
    datafile['sdkKey'] = sdk_key
    datafile
  end
  let(:config_body_integrations_JSON) { JSON.dump(config_body_integrations) }
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:version) { Optimizely::VERSION }
  let(:impression_log_url) { 'https://logx.optimizely.com/v1/events' }
  let(:conversion_log_url) { 'https://logx.optimizely.com/v1/events' }
  let(:project_instance) { Optimizely::Project.new(datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler, event_processor_options: {batch_size: 1}) }
  let(:project_config) { project_instance.config_manager.config }
  let(:time_now) { Time.now }
  let(:post_headers) { {'Content-Type' => 'application/json'} }
  after(:example) { project_instance.close }

  it 'has a version number' do
    expect(Optimizely::VERSION).not_to be_nil
  end

  it 'has engine value' do
    expect(Optimizely::CLIENT_ENGINE).not_to be_nil
  end

  describe '.initialize' do
    it 'should take in a custom logger when instantiating Project class' do
      class CustomLogger # rubocop:disable Lint/ConstantDefinitionInBlock
        def log(_level, log_message)
          log_message
        end
      end

      logger = CustomLogger.new
      instance_with_logger = Optimizely::Project.new(datafile: config_body_JSON, logger: logger)
      expect(instance_with_logger.logger.log(Logger::INFO, 'test_message')).to eq('test_message')
      instance_with_logger.close
    end

    it 'should take in a custom error handler when instantiating Project class' do
      class CustomErrorHandler # rubocop:disable Lint/ConstantDefinitionInBlock
        def handle_error(error)
          error
        end
      end

      error_handler = CustomErrorHandler.new
      instance_with_error_handler = Optimizely::Project.new(datafile: config_body_JSON, error_handler: error_handler)
      expect(instance_with_error_handler.error_handler.handle_error('test_message')).to eq('test_message')
      instance_with_error_handler.close
    end

    it 'should log an error when datafile is null' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      Optimizely::Project.new(logger: spy_logger).close
    end

    it 'should log an error when datafile is empty' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      Optimizely::Project.new(datafile: '', logger: spy_logger).close
    end

    it 'should log an error when given a datafile that does not conform to the schema' do
      allow(spy_logger).to receive(:log).with(Logger::INFO, anything)
      allow(spy_logger).to receive(:log).with(Logger::DEBUG, anything)
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'SDK key not provided/cannot be found in the datafile. ODP may not work properly without it.')
      Optimizely::Project.new(datafile: '{"foo": "bar"}', logger: spy_logger).close
    end

    it 'should log an error when given an invalid logger' do
      allow(Optimizely::SimpleLogger).to receive(:new).and_return(spy_logger)
      allow(spy_logger).to receive(:log).with(Logger::DEBUG, anything)
      allow(spy_logger).to receive(:log).with(Logger::INFO, anything)
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'Provided logger is in an invalid format.')

      class InvalidLogger; end # rubocop:disable Lint/ConstantDefinitionInBlock
      Optimizely::Project.new(datafile: config_body_JSON, logger: InvalidLogger.new).close
    end

    it 'should log an error when given an invalid event_dispatcher' do
      allow_any_instance_of(Optimizely::SimpleLogger).to receive(:log).with(Logger::INFO, anything)
      allow_any_instance_of(Optimizely::SimpleLogger).to receive(:log).with(Logger::DEBUG, anything)
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided event_dispatcher is in an invalid format.')

      class InvalidEventDispatcher; end # rubocop:disable Lint/ConstantDefinitionInBlock
      Optimizely::Project.new(datafile: config_body_JSON, event_dispatcher: InvalidEventDispatcher.new).close
    end

    it 'should log an error when given an invalid error_handler' do
      allow_any_instance_of(Optimizely::SimpleLogger).to receive(:log).with(Logger::INFO, anything)
      allow_any_instance_of(Optimizely::SimpleLogger).to receive(:log).with(Logger::DEBUG, anything)
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided error_handler is in an invalid format.')

      class InvalidErrorHandler; end # rubocop:disable Lint/ConstantDefinitionInBlock
      Optimizely::Project.new(datafile: config_body_JSON, error_handler: InvalidErrorHandler.new).close
    end

    it 'should not validate the JSON schema of the datafile when skip_json_validation is true' do
      project_instance.close
      expect(Optimizely::Helpers::Validator).not_to receive(:datafile_valid?)

      Optimizely::Project.new(datafile: config_body_JSON, skip_json_validation: true).close
    end

    it 'should be invalid when datafile contains integrations missing key' do
      # allow(Optimizely::SimpleLogger).to receive(:new).and_return(spy_logger)
      allow(spy_logger).to receive(:log).with(Logger::INFO, anything)
      allow(spy_logger).to receive(:log).with(Logger::DEBUG, anything)
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'SDK key not provided/cannot be found in the datafile. ODP may not work properly without it.')
      config = OptimizelySpec.deep_clone(config_body_integrations)
      config['integrations'][0].delete('key')
      integrations_json = JSON.dump(config)

      Optimizely::Project.new(datafile: integrations_json, logger: spy_logger)
    end

    it 'should be valid when datafile contains integrations with only key' do
      config = OptimizelySpec.deep_clone(config_body_integrations)
      config['integrations'].clear
      config['integrations'].push('key' => '123')
      integrations_json = JSON.dump(config)

      project_instance = Optimizely::Project.new(datafile: integrations_json)
      expect(project_instance.is_valid).to be true
    end

    it 'should be valid when datafile contains integrations with arbitrary fields' do
      config = OptimizelySpec.deep_clone(config_body_integrations)
      config['integrations'].clear
      config['integrations'].push('key' => 'future', 'any-key-1' => 1, 'any-key-2' => 'any-value-2')
      integrations_json = JSON.dump(config)

      project_instance = Optimizely::Project.new(datafile: integrations_json)
      expect(project_instance.is_valid).to be true
    end

    it 'should log and raise an error when provided a datafile that is not JSON and skip_json_validation is true' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect_any_instance_of(Optimizely::RaiseErrorHandler).to receive(:handle_error).once.with(Optimizely::InvalidInputError)

      Optimizely::Project.new(datafile: 'this is not JSON', logger: spy_logger, error_handler: Optimizely::RaiseErrorHandler.new, skip_json_validation: true)
    end

    it 'should log an error when provided an invalid JSON datafile and skip_json_validation is true' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')

      Optimizely::Project.new(datafile: '{"version": "2", "foo": "bar"}', logger: spy_logger, skip_json_validation: true)
    end

    it 'should log and raise an error when provided a datafile of unsupported version' do
      config_body_invalid_json = JSON.parse(config_body_invalid_JSON)
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, "This version of the Ruby SDK does not support the given datafile version: #{config_body_invalid_json['version']}.")

      expect { Optimizely::Project.new(datafile: config_body_invalid_JSON, logger: spy_logger, error_handler: Optimizely::RaiseErrorHandler.new, skip_json_validation: true) }.to raise_error(Optimizely::InvalidDatafileVersionError, 'This version of the Ruby SDK does not support the given datafile version: 5.')
    end
  end

  describe '#create_user_context' do
    it 'should log and return nil when user ID is non string' do
      expect(project_instance.create_user_context(nil)).to eq(nil)
      expect(project_instance.create_user_context(5)).to eq(nil)
      expect(project_instance.create_user_context(5.5)).to eq(nil)
      expect(project_instance.create_user_context(true)).to eq(nil)
      expect(project_instance.create_user_context({})).to eq(nil)
      expect(project_instance.create_user_context([])).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'User ID is invalid').exactly(6).times
    end

    it 'should return nil when attributes are invalid' do
      expect(Optimizely::Helpers::Validator).to receive(:attributes_valid?).once.with('invalid')
      expect(error_handler).to receive(:handle_error).once.with(Optimizely::InvalidAttributeFormatError)
      expect(project_instance.create_user_context(
               'test_user',
               'invalid'
             )).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided attributes are in an invalid format.')
    end

    it 'should return OptimizelyUserContext with valid user ID and attributes' do
      expect(project_instance.create_user_context(
               'test_user',
               'browser' => 'chrome'
             )).to be_instance_of(Optimizely::OptimizelyUserContext)
    end

    it 'should send identify event when called with odp enabled' do
      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger)
      expect(project.odp_manager).to receive(:identify_user).with({user_id: 'tester'})
      project.create_user_context('tester')

      project.close
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
              variation_id: '111128',
              metadata: {
                flag_key: '',
                rule_key: 'test_experiment',
                rule_type: 'experiment',
                variation_key: 'control',
                enabled: true
              }
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

      variation_to_return = project_config.get_variation_from_id('test_experiment', '111128')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return([variation_to_return, nil])
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_config).to receive(:get_audience_ids_for_experiment)
        .with('test_experiment')
        .and_return([])

      stub_request(:post, impression_log_url).with(query: params)

      expect(project_instance.activate('test_experiment', 'test_user')).to eq('control')

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
      expect(project_instance.decision_service.bucketer).to have_received(:bucket).once
    end

    it 'should properly activate a user, invoke Event object with right params, and return variation after a forced variation call' do
      params = @expected_activate_params

      project_instance.decision_service.set_forced_variation(project_config, 'test_experiment', 'test_user', 'control')
      variation_to_return = project_instance.decision_service.get_forced_variation(project_config, 'test_experiment', 'test_user')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_config).to receive(:get_audience_ids_for_experiment)
        .with('test_experiment')
        .and_return([])

      stub_request(:post, impression_log_url).with(query: params)

      expect(project_instance.activate('test_experiment', 'test_user')).to eq('control')

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

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

      params[:visitors][0][:snapshots][0][:decisions][0][:metadata] = {
        flag_key: '',
        rule_key: 'test_experiment_with_audience',
        rule_type: 'experiment',
        variation_key: 'control_with_audience',
        enabled: true
      }

      variation_to_return = project_config.get_variation_from_id('test_experiment_with_audience', '122228')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

      expect(project_instance.activate('test_experiment_with_audience', 'test_user', 'browser_type' => 'firefox'))
        .to eq('control_with_audience')

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
      expect(project_instance.decision_service.bucketer).to have_received(:bucket).once
    end

    describe '.typed audiences' do
      before(:example) do
        @project_typed_audience_instance = Optimizely::Project.new(datafile: JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES), logger: spy_logger, error_handler: error_handler, event_processor_options: {batch_size: 1})
        @project_config = @project_typed_audience_instance.config_manager.config
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

      after(:example) do
        @project_typed_audience_instance.close
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

        variation_to_return = @project_config.get_variation_from_id('typed_audience_experiment', '1423767503')

        params[:visitors][0][:snapshots][0][:decisions][0][:metadata] = {
          flag_key: '',
          rule_key: 'typed_audience_experiment',
          rule_type: 'experiment',
          variation_key: variation_to_return['key'],
          enabled: true
        }

        allow(@project_typed_audience_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        # Should be included via exact match string audience with id '3468206642'
        expect(@project_typed_audience_instance.activate('typed_audience_experiment', 'test_user', 'house' => 'Gryffindor'))
          .to eq('A')

        # wait for batch processing thread to send event
        sleep 0.1 until @project_typed_audience_instance.event_processor.event_queue.empty?

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

        variation_to_return = @project_config.get_variation_from_id('typed_audience_experiment', '1423767503')

        params[:visitors][0][:snapshots][0][:decisions][0][:metadata] = {
          flag_key: '',
          rule_key: 'typed_audience_experiment',
          rule_type: 'experiment',
          variation_key: variation_to_return['key'],
          enabled: true
        }

        allow(@project_typed_audience_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        # Should be included via exact match number audience with id '3468206646'
        expect(@project_typed_audience_instance.activate('typed_audience_experiment', 'test_user', 'lasers' => 45.5))
          .to eq('A')

        # wait for batch processing thread to send event
        sleep 0.1 until @project_typed_audience_instance.event_processor.event_queue.empty?

        expect(@project_typed_audience_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
        expect(@project_typed_audience_instance.decision_service.bucketer).to have_received(:bucket).once
      end

      it 'should return nil when typed audience conditions mismatch' do
        variation_to_return = @project_config.get_variation_from_id('typed_audience_experiment', '1423767503')
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

        variation_to_return = @project_config.get_variation_from_id('audience_combinations_experiment', '1423767504')

        params[:visitors][0][:snapshots][0][:decisions][0][:metadata] = {
          flag_key: '',
          rule_key: 'audience_combinations_experiment',
          rule_type: 'experiment',
          variation_key: variation_to_return['key'],
          enabled: true
        }

        allow(@project_typed_audience_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        expect(@project_typed_audience_instance.activate('audience_combinations_experiment', 'test_user', user_attributes))
          .to eq('A')

        # wait for batch processing thread to send event
        sleep 0.1 until @project_typed_audience_instance.event_processor.event_queue.empty?

        expect(@project_typed_audience_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
        expect(@project_typed_audience_instance.decision_service.bucketer).to have_received(:bucket).once
      end

      it 'should return nil when complex audience conditions do not match' do
        user_attributes = {'house' => 'Hufflepuff', 'lasers' => 45.5}
        # variation_to_return = @project_typed_audience_instance.config_manager.config.get_variation_from_id('audience_combinations_experiment', '1423767504')
        allow(@project_typed_audience_instance.decision_service.bucketer).to receive(:bucket)
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        expect(@project_typed_audience_instance.activate('audience_combinations_experiment', 'test_user', user_attributes))
          .to eq(nil)

        # wait for batch processing thread to send event
        sleep 0.1 until project_instance.event_processor.event_queue.empty?

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

      params[:visitors][0][:snapshots][0][:decisions][0][:metadata] = {
        flag_key: '',
        rule_key: 'test_experiment_with_audience',
        rule_type: 'experiment',
        variation_key: 'control_with_audience',
        enabled: true
      }

      variation_to_return = project_config.get_variation_from_id('test_experiment_with_audience', '122228')
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

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

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

      params[:visitors][0][:snapshots][0][:decisions][0][:metadata] = {
        flag_key: '',
        rule_key: 'test_experiment_with_audience',
        rule_type: 'experiment',
        variation_key: 'control_with_audience',
        enabled: true
      }

      variation_to_return = project_config.get_variation_from_id('test_experiment_with_audience', '122228')
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

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

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

      project_instance.decision_service.set_forced_variation(project_config, 'test_experiment_with_audience', 'test_user', 'variation_with_audience')
      variation_to_return = project_instance.decision_service.get_forced_variation(project_config, 'test_experiment', 'test_user')

      params[:visitors][0][:snapshots][0][:decisions][0][:metadata] = {
        flag_key: '',
        rule_key: 'test_experiment_with_audience',
        rule_type: 'experiment',
        variation_key: 'variation_with_audience',
        enabled: true
      }

      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

      expect(project_instance.activate('test_experiment_with_audience', 'test_user', 'browser_type' => 'firefox'))
        .to eq('variation_with_audience')

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

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

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Not activating user 'test_user'.")
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
    end

    it 'should log and send activate notification when an impression event is dispatched' do
      def callback(_args); end
      project_instance.notification_center.add_notification_listener(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
        method(:callback)
      )
      variation_to_return = project_config.get_variation_from_id('test_experiment', '111128')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_config).to receive(:get_audience_ids_for_experiment)
        .with('test_experiment')
        .and_return([])
      experiment = project_config.get_experiment_from_key('test_experiment')

      # Decision listener
      expect(project_instance.notification_center).to receive(:send_notifications).with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION], any_args
      ).ordered

      # Log event
      expect(project_instance.notification_center).to receive(:send_notifications).with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args
      ).ordered

      # Activate listener
      expect(project_instance.notification_center).to receive(:send_notifications).with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
        experiment, 'test_user', nil, variation_to_return,
        instance_of(Optimizely::Event)
      )

      project_instance.activate('test_experiment', 'test_user')

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Activating user 'test_user' in experiment 'test_experiment'.")
    end

    it 'should log when an exception has occurred during dispatching the impression event' do
      params = @expected_activate_params
      stub_request(:post, impression_log_url).with(query: params)
      log_event = Optimizely::Event.new(:post, impression_log_url, params, post_headers)
      allow(Optimizely::EventFactory).to receive(:create_log_event).and_return(log_event)

      variation_to_return = project_config.get_variation_from_id('test_experiment', '111128')
      allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(any_args).and_raise(RuntimeError)
      project_instance.activate('test_experiment', 'test_user')

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Error dispatching event: #{log_event} RuntimeError.")
    end

    it 'should raise an exception when called with invalid attributes' do
      expect { project_instance.activate('test_experiment', 'test_user', 'invalid') }
        .to raise_error(Optimizely::InvalidAttributeFormatError)

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?
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

      params[:visitors][0][:snapshots][0][:decisions][0][:metadata] = {
        flag_key: '',
        rule_key: 'test_experiment_with_audience',
        rule_type: 'experiment',
        variation_key: 'variation_with_audience',
        enabled: true
      }

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(Optimizely::Audience).to receive(:user_in_experiment?)

      expect(project_instance.activate('test_experiment_with_audience', 'forced_audience_user', 'browser_type' => 'wrong_browser'))
        .to eq('variation_with_audience')

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
      expect(Optimizely::Audience).to_not have_received(:user_in_experiment?)
    end

    it 'should log an error when called with an invalid Project object' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      invalid_project.activate('test_exp', 'test_user')
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Optimizely instance is not valid. Failing 'activate'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event)
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.activate('test_experiment', 'test_user')).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'activate'."
      )
    end

    describe '.decision listener' do
      it 'should call decision listener when user not in experiment' do
        expect(project_instance.notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature-test', 'test_user', {},
          experiment_key: 'test_experiment_with_audience', variation_key: nil
        )

        project_instance.activate('test_experiment_with_audience', 'test_user')
      end

      it 'should call decision listener when user in experiment' do
        variation_to_return = project_config.get_variation_from_id('test_experiment', '111128')
        allow(project_instance.decision_service.bucketer).to receive(:bucket).and_return(variation_to_return)
        expect(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        # Decision listener
        expect(project_instance.notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'ab-test', 'test_user', {},
          experiment_key: 'test_experiment', variation_key: 'control'
        ).ordered

        # Activate listener
        expect(project_instance.notification_center).to receive(:send_notifications).ordered

        project_instance.activate('test_experiment', 'test_user')
      end
    end

    describe '.Optimizely with config manager' do
      before(:example) do
        stub_request(:post, impression_log_url)
        stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
          .with(
            headers: {
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: config_body_JSON, headers: {})
      end

      it 'should update config, send update notification when url is provided' do
        notification_center = Optimizely::NotificationCenter.new(spy_logger, error_handler)

        expect(notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE]
        ).ordered

        expect(notification_center).to receive(:send_notifications).ordered

        expect(notification_center).to receive(:send_notifications).ordered
        http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
          sdk_key: sdk_key,
          url: "https://cdn.optimizely.com/datafiles/#{sdk_key}.json",
          notification_center: notification_center
        )

        custom_project_instance = Optimizely::Project.new(
          logger: spy_logger, error_handler: error_handler,
          config_manager: http_project_config_manager, notification_center: notification_center
        )

        sleep 0.1 until http_project_config_manager.ready?

        expect(http_project_config_manager.config).not_to eq(nil)
        expect(custom_project_instance.activate('test_experiment', 'test_user')).not_to eq(nil)
        custom_project_instance.close
      end

      it 'should update config, send update notification when sdk key is provided' do
        notification_center = Optimizely::NotificationCenter.new(spy_logger, error_handler)

        expect(notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE]
        ).ordered

        expect(notification_center).to receive(:send_notifications).ordered
        expect(notification_center).to receive(:send_notifications).ordered

        http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
          sdk_key: sdk_key,
          notification_center: notification_center
        )

        custom_project_instance = Optimizely::Project.new(
          logger: spy_logger, error_handler: error_handler,
          config_manager: http_project_config_manager, notification_center: notification_center
        )

        sleep 0.1 until http_project_config_manager.ready?

        expect(http_project_config_manager.config).not_to eq(nil)
        expect(custom_project_instance.activate('test_experiment', 'test_user')).not_to eq(nil)
        custom_project_instance.close
      end
    end

    describe '.Optimizely with sdk key' do
      before(:example) do
        stub_request(:post, impression_log_url)
        stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
          .with(
            headers: {
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: config_body_JSON, headers: {})
      end
      it 'should update config, send update notification when sdk key is provided' do
        notification_center = Optimizely::NotificationCenter.new(spy_logger, error_handler)

        expect(notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE]
        ).ordered

        expect(notification_center).to receive(:send_notifications).ordered
        expect(notification_center).to receive(:send_notifications).ordered

        custom_project_instance = Optimizely::Project.new(
          logger: spy_logger, error_handler: error_handler,
          sdk_key: sdk_key, notification_center: notification_center
        )

        sleep 0.1 until custom_project_instance.config_manager.ready?

        expect(custom_project_instance.is_valid).to be true
        expect(custom_project_instance.activate('test_experiment', 'test_user')).not_to eq(nil)
        custom_project_instance.close
      end
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

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should properly track an event by calling dispatch_event with right params after forced variation' do
      project_instance.decision_service.set_forced_variation(project_config, 'test_experiment', 'test_user', 'variation')
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user')

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, @expected_track_event_params, post_headers)).once
    end

    it 'should properly track an event with tags even when the project does not have a custom logger' do
      custom_project_instance = Optimizely::Project.new(datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler, event_processor_options: {batch_size: 1})

      params = @expected_track_event_params
      params[:visitors][0][:snapshots][0][:events][0][:tags] = {revenue: 42}

      custom_project_instance.decision_service.set_forced_variation(project_config, 'test_experiment', 'test_user', 'variation')
      allow(custom_project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      custom_project_instance.track('test_event', 'test_user', nil, revenue: 42)

      # wait for batch processing thread to send event
      sleep 0.1 until custom_project_instance.event_processor.event_queue.empty?

      expect(custom_project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
      custom_project_instance.close
    end

    it 'should log a message if an exception has occurred during dispatching of the event' do
      params = @expected_track_event_params
      stub_request(:post, conversion_log_url).with(query: params)
      log_event = Optimizely::Event.new(:post, conversion_log_url, params, post_headers)
      allow(Optimizely::EventFactory).to receive(:create_log_event).and_return(log_event)
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(any_args).and_raise(RuntimeError)

      project_instance.track('test_event', 'test_user')

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Error dispatching event: #{log_event} RuntimeError.")
    end

    it 'should send track notification and properly track an event by calling dispatch_event with right params with revenue provided' do
      params = @expected_track_event_params
      params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 42,
                                                             tags: {'revenue' => 42})

      def callback(_args); end
      project_instance.notification_center.add_notification_listener(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK],
        method(:callback)
      )
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      conversion_event = Optimizely::Event.new(:post, conversion_log_url, params, post_headers)

      expect(project_instance.notification_center).to receive(:send_notifications)
        .with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args
        ).ordered

      expect(project_instance.notification_center).to receive(:send_notifications)
        .with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:TRACK],
          'test_event', 'test_user', nil, {'revenue' => 42}, conversion_event
        )

      project_instance.track('test_event', 'test_user', nil, 'revenue' => 42)

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

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

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    describe '.typed audiences' do
      before(:example) do
        @project_typed_audience_instance = Optimizely::Project.new(datafile: JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES), logger: spy_logger, error_handler: error_handler, event_processor_options: {batch_size: 1})
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
      after(:example) do
        @project_typed_audience_instance.close
      end

      it 'should call dispatch_event with right params when attributes are provided' do
        # Should be included via substring match string audience with id '3988293898'
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        @project_typed_audience_instance.track('item_bought', 'test_user', 'house' => 'Welcome to Slytherin!')

        # wait for batch processing thread to send event
        sleep 0.1 until @project_typed_audience_instance.event_processor.event_queue.empty?

        expect(@project_typed_audience_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, @expected_event_params, post_headers)).once
      end

      it 'should call dispatch_event even if typed audience conditions do not match' do
        params = @expected_event_params
        params[:visitors][0][:attributes][0][:value] = 'Welcome to Hufflepuff!'
        allow(@project_typed_audience_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        @project_typed_audience_instance.track('item_bought', 'test_user', 'house' => 'Welcome to Hufflepuff!')

        # wait for batch processing thread to send event
        sleep 0.1 until @project_typed_audience_instance.event_processor.event_queue.empty?

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

        # wait for batch processing thread to send event
        sleep 0.1 until @project_typed_audience_instance.event_processor.event_queue.empty?

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

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should call dispatch_event when tracking an event even if experiment is not running' do
      params = @expected_track_event_params
      params[:visitors][0][:snapshots][0][:events][0][:entity_id] = '111098'
      params[:visitors][0][:snapshots][0][:events][0][:key] = 'test_event_not_running'
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event_not_running', 'test_user')

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should log when a conversion event is dispatched' do
      params = @expected_track_event_params
      params[:visitors][0][:snapshots][0][:events][0].merge!(
        revenue: 42,
        tags: {'revenue' => 42}
      )
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user', nil, 'revenue' => 42)
      expect(spy_logger).to have_received(:log).with(Logger::INFO, "Tracking event 'test_event' for user 'test_user'.")
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
      allow(project_config).to receive(:get_event_from_key).with(any_args).and_return(nil)
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

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(Optimizely::Audience).to_not have_received(:user_in_experiment?)
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should log an error when called with an invalid Project object' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      invalid_project.track('test_event', 'test_user')
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Optimizely instance is not valid. Failing 'track'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.track('test_event', 'test_user')).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'track'."
      )
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

    it 'should log and raise an exception when called with attributes in an invalid format' do
      expect_any_instance_of(Optimizely::RaiseErrorHandler).to receive(:handle_error).once.with(Optimizely::InvalidAttributeFormatError)
      expect(project_instance.get_variation('test_experiment_with_audience', 'test_user', 'invalid_attributes')).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided attributes are in an invalid format.')
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
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      invalid_project.get_variation('test_exp', 'test_user')
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Optimizely instance is not valid. Failing 'get_variation'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.get_variation('test_exp', 'test_user')).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'get_variation'."
      )
    end

    describe '.decision listener' do
      it 'should call decision listener when user in experiment' do
        expect(project_instance.notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'ab-test', 'test_user', {'browser_type' => 'firefox'},
          experiment_key: 'test_experiment', variation_key: 'control'
        )

        project_instance.get_variation('test_experiment', 'test_user', 'browser_type' => 'firefox')
      end

      it 'should call decision listener when user not in experiment' do
        expect(project_instance.notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'ab-test', 'test_user', {'browser_type' => 'chrome'},
          experiment_key: 'test_experiment', variation_key: 'control'
        )

        project_instance.get_variation('test_experiment', 'test_user', 'browser_type' => 'chrome')
      end

      it 'should call decision listener with type feature-test when get_variation returns feature experiment variation' do
        expect(project_instance.notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature-test', 'test_user', {'browser_type' => 'chrome'},
          experiment_key: 'test_experiment_double_feature', variation_key: 'control'
        )

        project_instance.get_variation('test_experiment_double_feature', 'test_user', 'browser_type' => 'chrome')
      end
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
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      expect(invalid_project.is_feature_enabled('totally_invalid_feature_key', 'test_user')).to be false
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Optimizely instance is not valid. Failing 'is_feature_enabled'.")
      invalid_project.close
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

    it 'should return false and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.is_feature_enabled('multi_variate_feature', 'test_user')).to be(false)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'is_feature_enabled'."
      )
    end

    it 'should return false and send an impression when the user is not bucketed into any variation' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(nil)

      expect(project_instance.is_feature_enabled('multi_variate_feature', 'test_user')).to be(false)

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'multi_variate_feature' is not enabled for user 'test_user'.")
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(instance_of(Optimizely::Event)).once
    end

    it 'should return true and send an impression if the user is not bucketed into a feature experiment' do
      experiment_to_return = config_body['rollouts'][0]['experiments'][0]
      variation_to_return = experiment_to_return['variations'][0]

      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
      )

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user')).to be true

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'boolean_single_variable_feature' is enabled for user 'test_user'.")
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(instance_of(Optimizely::Event)).once
    end

    it 'should return false, if the user is bucketed into a feature rollout but the featureEnabled property is false' do
      experiment_to_return = config_body['rollouts'][0]['experiments'][1]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
      )
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
      expect(variation_to_return['featureEnabled']).to be false

      expect(project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user')).to be false

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'boolean_single_variable_feature' is not enabled for user 'test_user'.")
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(instance_of(Optimizely::Event)).once
    end

    it 'should return true, if the user is bucketed into a feature rollout when featureEnabled property is true' do
      experiment_to_return = config_body['rollouts'][0]['experiments'][0]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
      )
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
      expect(variation_to_return['featureEnabled']).to be true

      expect(project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user')).to be true

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'boolean_single_variable_feature' is enabled for user 'test_user'.")
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(instance_of(Optimizely::Event)).once
    end

    describe '.typed audiences' do
      before(:example) do
        @project_typed_audience_instance = Optimizely::Project.new(datafile: JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES), logger: spy_logger, error_handler: error_handler)
        stub_request(:post, impression_log_url)
      end
      after(:example) do
        @project_typed_audience_instance.close
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

        expect(spy_logger).to have_received(:log).twice.with(Logger::INFO, "Feature 'feat' is enabled for user 'test_user'.")
      end

      it 'should return false for feature rollout when typed audience mismatch' do
        expect(@project_typed_audience_instance.is_feature_enabled('feat', 'test_user', {})).to be false

        expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'feat' is not enabled for user 'test_user'.")
      end

      it 'should return true for feature rollout with complex audience match' do
        # Should be included via substring match string audience with id '3988293898', and
        # exists audience with id '3988293899'
        user_attributes = {'house' => '...Slytherinnn...sss.', 'favorite_ice_cream' => 'matcha'}

        expect(@project_typed_audience_instance.is_feature_enabled(
                 'feat2', 'test_user', user_attributes
               )).to be true

        expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'feat2' is enabled for user 'test_user'.")
      end

      it 'should return false for feature rollout with complex audience mismatch' do
        # Should be excluded - substring match string audience with id '3988293898' does not match,
        # and no audience in the other branch of the 'and' matches either
        expect(@project_typed_audience_instance.is_feature_enabled('feat2', 'test_user', 'house' => 'Lannister')).to be false

        expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'feat2' is not enabled for user 'test_user'.")
      end
    end

    it 'should return true, send activate notification and an impression if the user is bucketed into a feature experiment' do
      def callback(_args); end
      project_instance.notification_center.add_notification_listener(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
        method(:callback)
      )

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      experiment_to_return = config_body['experiments'][3]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
      )

      expect(project_instance.notification_center).to receive(:send_notifications)
        .with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args
        )

      expect(project_instance.notification_center).to receive(:send_notifications)
        .with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
          experiment_to_return, 'test_user', nil, variation_to_return,
          instance_of(Optimizely::Event)
        ).ordered

      expect(project_instance.notification_center).to receive(:send_notifications)
        .with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION], any_args
        ).ordered

      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.is_feature_enabled('multi_variate_feature', 'test_user')).to be true

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Activating user 'test_user' in experiment 'test_experiment_multivariate'.")
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'multi_variate_feature' is enabled for user 'test_user'.")
    end

    it 'should return false and send impression if the user is bucketed into a feature experiment but the featureEnabled property is false' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      experiment_to_return = config_body['experiments'][3]
      variation_to_return = experiment_to_return['variations'][1]
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
      )
      expect(variation_to_return['featureEnabled']).to be false
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.is_feature_enabled('multi_variate_feature', 'test_user')).to be false

      # wait for batch processing thread to send event
      sleep 0.1 until project_instance.event_processor.event_queue.empty?

      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(instance_of(Optimizely::Event)).once
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Feature 'multi_variate_feature' is not enabled for user 'test_user'.")
    end

    describe '.decision listener' do
      before(:example) do
        stub_request(:post, impression_log_url)
      end

      it 'should call decision listener when user is bucketed into a feature experiment with featureEnabled property is true' do
        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][0]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        )

        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

        # Activate listener
        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args
        )

        # Decision listener called when the user is in experiment with variation feature on.
        expect(variation_to_return['featureEnabled']).to be true
        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {},
          feature_enabled: true,
          feature_key: 'multi_variate_feature',
          source: 'feature-test',
          source_info: {
            experiment_key: 'test_experiment_multivariate',
            variation_key: 'Fred'
          }
        ).ordered

        project_instance.is_feature_enabled('multi_variate_feature', 'test_user')

        # wait for batch processing thread to send event
        sleep 0.1 until project_instance.event_processor.event_queue.empty?
      end

      it 'should call decision listener when user is bucketed into a feature experiment with featureEnabled property is false' do
        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][1]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        )

        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args
        ).ordered

        # DECISION listener called when the user is in experiment with variation feature off.
        expect(variation_to_return['featureEnabled']).to be false
        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'chrome'},
          feature_enabled: false,
          feature_key: 'multi_variate_feature',
          source: 'feature-test',
          source_info: {
            experiment_key: 'test_experiment_multivariate',
            variation_key: 'Feorge'
          }
        )

        project_instance.is_feature_enabled('multi_variate_feature', 'test_user', 'browser_type' => 'chrome')

        # wait for batch processing thread to send event
        sleep 0.1 until project_instance.event_processor.event_queue.empty?
      end

      it 'should call decision listener when user is bucketed into rollout with featureEnabled property is true' do
        experiment_to_return = config_body['rollouts'][0]['experiments'][0]
        variation_to_return = experiment_to_return['variations'][0]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
        )
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

        # DECISION listener called when the user is in rollout with variation feature true.
        expect(variation_to_return['featureEnabled']).to be true

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args
        ).ordered
        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: true,
          feature_key: 'boolean_single_variable_feature',
          source: 'rollout',
          source_info: {}
        )

        project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user', 'browser_type' => 'firefox')

        # wait for batch processing thread to send event
        sleep 0.1 until project_instance.event_processor.event_queue.empty?
      end

      it 'should call decision listener when user is bucketed into rollout with featureEnabled property is false' do
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(Optimizely::DecisionService::Decision)

        # DECISION listener called when the user is in rollout with variation feature off.
        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {},
          feature_enabled: false,
          feature_key: 'boolean_single_variable_feature',
          source: 'rollout',
          source_info: {}
        )

        project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user')
      end

      it 'call decision listener when the user is not bucketed into any experiment or rollout' do
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(nil)
        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args
        ).ordered

        expect(project_instance.notification_center).to receive(:send_notifications).with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: false,
          feature_key: 'multi_variate_feature',
          source: 'rollout',
          source_info: {}
        )

        project_instance.is_feature_enabled('multi_variate_feature', 'test_user', 'browser_type' => 'firefox')

        # wait for batch processing thread to send event
        sleep 0.1 until project_instance.event_processor.event_queue.empty?
      end
    end
  end

  describe '#get_enabled_features' do
    it 'should return empty when called with invalid project config' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      expect(invalid_project.get_enabled_features('test_user')).to be_empty
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Optimizely instance is not valid. Failing 'get_enabled_features'.")
      invalid_project.close
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

    it 'should return empty and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.get_enabled_features('test_user', 'browser_type' => 'chrome')).to be_empty
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'get_enabled_features'."
      )
    end

    it 'should return only enabled feature flags keys' do
      # Sets all feature-flags keys with randomly assigned status
      features_keys = project_config.feature_flags.map do |item|
        {key: (item['key']).to_s, value: [true, false].sample} # '[true, false].sample' generates random boolean
      end

      enabled_features = features_keys.map { |x| x[:key] if x[:value] == true }.compact
      disabled_features = features_keys.map { |x| x[:key] if x[:value] == false }.compact

      features_keys.each do |feature|
        allow(project_instance).to receive(:is_feature_enabled).with(feature[:key], 'test_user', {'browser_type' => 'chrome'}).and_return(feature[:value])
      end

      # Checks enabled features are returned
      expect(project_instance.get_enabled_features('test_user', 'browser_type' => 'chrome')).to include(*enabled_features)
      expect(project_instance.get_enabled_features('test_user', 'browser_type' => 'chrome').length).to eq(enabled_features.length)

      # Checks prevented features should not return
      expect(project_instance.get_enabled_features('test_user', 'browser_type' => 'chrome')).not_to include(*disabled_features)
    end

    describe '.decision listener' do
      it 'should return enabled features and call decision listener for all features' do
        def callback(_args); end
        project_instance.notification_center.add_notification_listener(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE],
          method(:callback)
        )

        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

        enabled_features = %w[boolean_feature integer_single_variable_feature]

        experiment_to_return = config_body['experiments'][3]
        rollout_to_return = config_body['rollouts'][0]['experiments'][0]

        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(
          Optimizely::DecisionService::Decision.new(
            experiment_to_return,
            experiment_to_return['variations'][0],
            Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          ),
          nil,
          Optimizely::DecisionService::Decision.new(
            rollout_to_return,
            rollout_to_return['variations'][0],
            Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
          ),
          Optimizely::DecisionService::Decision.new(
            experiment_to_return,
            experiment_to_return['variations'][1],
            Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          ),
          nil,
          nil,
          nil,
          nil
        )

        expect(project_instance.notification_center).to receive(:send_notifications).exactly(10).times.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args
        )

        expect(project_instance.notification_center).to receive(:send_notifications).exactly(10).times.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:ACTIVATE], any_args
        )

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: true,
          feature_key: 'boolean_feature',
          source: 'feature-test',
          source_info: {
            experiment_key: 'test_experiment_multivariate',
            variation_key: 'Fred'
          }
        ).ordered

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: false,
          feature_key: 'double_single_variable_feature',
          source: 'rollout',
          source_info: {}
        ).ordered

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: true,
          feature_key: 'integer_single_variable_feature',
          source: 'rollout',
          source_info: {}
        ).ordered

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: false,
          feature_key: 'boolean_single_variable_feature',
          source: 'feature-test',
          source_info: {
            experiment_key: 'test_experiment_multivariate',
            variation_key: 'Feorge'
          }
        ).ordered

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: false,
          feature_key: 'string_single_variable_feature',
          source: 'rollout',
          source_info: {}
        ).ordered

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: false,
          feature_key: 'multi_variate_feature',
          source: 'rollout',
          source_info: {}
        ).ordered

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: false,
          feature_key: 'mutex_group_feature',
          source: 'rollout',
          source_info: {}
        ).ordered

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: false,
          feature_key: 'empty_feature',
          source: 'rollout',
          source_info: {}
        ).ordered

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: false,
          feature_key: 'json_single_variable_feature',
          source: 'rollout',
          source_info: {}
        ).ordered

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature', 'test_user', {'browser_type' => 'firefox'},
          feature_enabled: false,
          feature_key: 'all_variables_feature',
          source: 'rollout',
          source_info: {}
        ).ordered

        expect(project_instance.get_enabled_features('test_user', 'browser_type' => 'firefox')).to eq(enabled_features)
      end
    end
  end

  describe '#get_feature_variable_string' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should return nil when called with invalid project config' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      expect(invalid_project.get_feature_variable_string('string_single_variable_feature', 'string_variable', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Optimizely instance is not valid. Failing 'get_feature_variable_string'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.get_feature_variable_string('string_single_variable_feature', 'string_variable', user_id, user_attributes)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'get_feature_variable_string'."
      )
    end

    describe 'when the feature flag is enabled for the user' do
      describe 'and a variable usage instance is not found' do
        it 'should return the default variable value' do
          variation_to_return = project_config.rollout_id_map['166661']['experiments'][0]['variations'][0]
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
                                                     "Variable value is not defined. Returning the default variable value 'wingardium leviosa' for variable 'string_variable'."
                                                   )
        end
      end

      describe 'and a variable usage instance is found' do
        describe 'and the variable type boolean is not a string' do
          it 'should log a warning' do
            variation_to_return = project_config.rollout_id_map['166660']['experiments'][0]['variations'][0]
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
            integer_feature = project_config.feature_flag_key_map['integer_single_variable_feature']
            experiment_to_return = project_config.experiment_id_map[integer_feature['experimentIds'][0]]
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
          experiment_to_return = project_config.experiment_key_map['test_experiment_with_feature_rollout']
          variation_to_return = experiment_to_return['variations'][0]
          decision_to_return = {
            'experiment' => experiment_to_return,
            'variation' => variation_to_return
          }
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.get_feature_variable_string('string_single_variable_feature', 'string_variable', user_id, user_attributes))
            .to eq('cta_1')

          expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
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
        expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::INFO,
                                                   "User 'test_user' was not bucketed into experiment or rollout for feature flag 'string_single_variable_feature'. Returning the default variable value 'wingardium leviosa'."
                                                 )
      end
    end

    describe 'when the specified feature flag is invalid' do
      it 'should log an error message and return nil' do
        expect(project_instance.get_feature_variable_string('totally_invalid_feature_key', 'string_variable', user_id, user_attributes))
          .to eq(nil)
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
                                                 .with(
                                                   Logger::ERROR,
                                                   "No feature variable was found for key 'invalid_string_variable' in feature flag 'string_single_variable_feature'."
                                                 )
      end
    end
  end

  describe '#get_feature_variable_json' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should return nil when called with invalid project config' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      expect(invalid_project.get_feature_variable_json('json_single_variable_feature', 'json_variable', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Optimizely instance is not valid. Failing 'get_feature_variable_json'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.get_feature_variable_json('json_single_variable_feature', 'json_variable', user_id, user_attributes)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'get_feature_variable_json'."
      )
    end

    describe 'when the feature flag is enabled for the user' do
      describe 'and a variable usage instance is not found' do
        it 'should return the default variable value' do
          variation_to_return = project_config.rollout_id_map['166661']['experiments'][0]['variations'][0]
          decision_to_return = {
            'experiment' => nil,
            'variation' => variation_to_return
          }
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.notification_center).to receive(:send_notifications).once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'feature-variable', 'test_user', {},
            feature_enabled: true,
            feature_key: 'json_single_variable_feature',
            source: 'rollout',
            variable_key: 'json_variable',
            variable_type: 'json',
            variable_value: {'val' => 'wingardium leviosa'},
            source_info: {}
          )

          expect(project_instance.get_feature_variable_json('json_single_variable_feature', 'json_variable', user_id, user_attributes))
            .to eq('val' => 'wingardium leviosa')
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::DEBUG,
                                                     "Variable value is not defined. Returning the default variable value '{ \"val\": \"wingardium leviosa\" }' for variable 'json_variable'."
                                                   )
        end
      end

      describe 'and a variable usage instance is found' do
        describe 'and the variable type boolean is not a json' do
          it 'should log a warning' do
            variation_to_return = project_config.rollout_id_map['166660']['experiments'][0]['variations'][0]
            decision_to_return = {
              'experiment' => nil,
              'variation' => variation_to_return
            }
            allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

            expect(project_instance.get_feature_variable_json('boolean_single_variable_feature', 'boolean_variable', user_id, user_attributes))
              .to eq(nil)
            expect(spy_logger).to have_received(:log).once
                                                     .with(
                                                       Logger::WARN,
                                                       "Requested variable as type 'json' but variable 'boolean_variable' is of type 'boolean'."
                                                     )
          end
        end

        describe 'and the variable type integer is not a json' do
          it 'should log a warning' do
            integer_feature = project_config.feature_flag_key_map['integer_single_variable_feature']
            experiment_to_return = project_config.experiment_id_map[integer_feature['experimentIds'][0]]
            variation_to_return = experiment_to_return['variations'][0]
            decision_to_return = {
              'experiment' => experiment_to_return,
              'variation' => variation_to_return
            }
            allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

            expect(project_instance.get_feature_variable_json('integer_single_variable_feature', 'integer_variable', user_id, user_attributes))
              .to eq(nil)
            expect(spy_logger).to have_received(:log).once
                                                     .with(
                                                       Logger::WARN,
                                                       "Requested variable as type 'json' but variable 'integer_variable' is of type 'integer'."
                                                     )
          end
        end

        it 'should return the variable value for the variation for the user is bucketed into' do
          experiment_to_return = project_config.experiment_key_map['test_experiment_with_feature_rollout']
          variation_to_return = experiment_to_return['variations'][0]
          decision_to_return = {
            'experiment' => experiment_to_return,
            'variation' => variation_to_return
          }
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.notification_center).to receive(:send_notifications).once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'feature-variable', 'test_user', {},
            feature_enabled: true,
            feature_key: 'json_single_variable_feature',
            source: 'rollout',
            variable_key: 'json_variable',
            variable_type: 'json',
            variable_value: {'value' => 'cta_1'},
            source_info: {}
          )

          expect(project_instance.get_feature_variable_json('json_single_variable_feature', 'json_variable', user_id, user_attributes))
            .to eq('value' => 'cta_1')

          expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value '{\"value\": \"cta_1\"}' for variable 'json_variable' of feature flag 'json_single_variable_feature'."
                                                   )
        end
      end
    end

    describe 'when the feature flag is not enabled for the user' do
      it 'should return the default variable value' do
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(nil)

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'feature-variable', 'test_user', {},
          feature_enabled: false,
          feature_key: 'json_single_variable_feature',
          source: 'rollout',
          variable_key: 'json_variable',
          variable_type: 'json',
          variable_value: {'val' => 'wingardium leviosa'},
          source_info: {}
        )

        expect(project_instance.get_feature_variable_json('json_single_variable_feature', 'json_variable', user_id, user_attributes))
          .to eq('val' => 'wingardium leviosa')
        expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::INFO,
                                                   "User 'test_user' was not bucketed into experiment or rollout for feature flag 'json_single_variable_feature'. Returning the default variable value '{ \"val\": \"wingardium leviosa\" }'."
                                                 )
      end
    end

    describe 'when the specified feature flag is invalid' do
      it 'should log an error message and return nil' do
        expect(project_instance.get_feature_variable_json('totally_invalid_feature_key', 'json_variable', user_id, user_attributes))
          .to eq(nil)
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::ERROR,
                                                   "Feature flag key 'totally_invalid_feature_key' is not in datafile."
                                                 )
        expect(spy_logger).to have_received(:log)
          .with(Logger::INFO, "No feature flag was found for key 'totally_invalid_feature_key'.")
      end
    end

    describe 'when the specified feature variable is invalid' do
      it 'should log an error message and return nil' do
        expect(project_instance.get_feature_variable_json('json_single_variable_feature', 'invalid_json_variable', user_id, user_attributes))
          .to eq(nil)
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::ERROR,
                                                   "No feature variable was found for key 'invalid_json_variable' in feature flag 'json_single_variable_feature'."
                                                 )
      end
    end
  end

  describe '#get_feature_variable_boolean' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should return nil when called with invalid project config' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      expect(invalid_project.get_feature_variable_boolean('boolean_single_variable_feature', 'boolean_variable', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Optimizely instance is not valid. Failing 'get_feature_variable_boolean'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.get_feature_variable_boolean('boolean_single_variable_feature', 'boolean_variable', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'get_feature_variable_boolean'."
      )
    end

    it 'should return the variable value for the variation for the user is bucketed into' do
      boolean_feature = project_config.feature_flag_key_map['boolean_single_variable_feature']
      rollout = project_config.rollout_id_map[boolean_feature['rolloutId']]
      variation_to_return = rollout['experiments'][0]['variations'][0]
      decision_to_return = {
        'experiment' => nil,
        'variation' => variation_to_return
      }
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.get_feature_variable_boolean('boolean_single_variable_feature', 'boolean_variable', user_id, user_attributes))
        .to eq(true)
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
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
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      expect(invalid_project.get_feature_variable_double('double_single_variable_feature', 'double_variable', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Optimizely instance is not valid. Failing 'get_feature_variable_double'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.get_feature_variable_double('double_single_variable_feature', 'double_variable', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'get_feature_variable_double'."
      )
    end

    it 'should return the variable value for the variation for the user is bucketed into' do
      double_feature = project_config.feature_flag_key_map['double_single_variable_feature']
      experiment_to_return = project_config.experiment_id_map[double_feature['experimentIds'][0]]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = {
        'experiment' => experiment_to_return,
        'variation' => variation_to_return
      }

      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.get_feature_variable_double('double_single_variable_feature', 'double_variable', user_id, user_attributes))
        .to eq(42.42)

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
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
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      expect(invalid_project.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Optimizely instance is not valid. Failing 'get_feature_variable_integer'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'get_feature_variable_integer'."
      )
    end

    it 'should return the variable value for the variation for the user is bucketed into' do
      integer_feature = project_config.feature_flag_key_map['integer_single_variable_feature']
      experiment_to_return = project_config.experiment_id_map[integer_feature['experimentIds'][0]]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = {
        'experiment' => experiment_to_return,
        'variation' => variation_to_return
      }

      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', user_id, user_attributes))
        .to eq(42)

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).once
                                               .with(
                                                 Logger::INFO,
                                                 "Got variable value '42' for variable 'integer_variable' of feature flag 'integer_single_variable_feature'."
                                               )
    end
  end

  describe '#get_all_feature_variables' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should return nil when called with invalid project config' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      expect(invalid_project.get_all_feature_variables('all_variables_feature', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Optimizely instance is not valid. Failing 'get_all_feature_variables'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.get_all_feature_variables('all_variables_feature', user_id, user_attributes)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'get_all_feature_variables'."
      )
    end

    describe 'when the feature flag is enabled for the user' do
      describe 'and a variable usage instance is not found' do
        it 'should return the default variable value' do
          Decision = Struct.new(:experiment, :variation, :source) # rubocop:disable Lint/ConstantDefinitionInBlock
          variation_to_return = project_config.rollout_id_map['166661']['experiments'][0]['variations'][0]
          decision_to_return = Decision.new({'key' => 'test-exp'}, variation_to_return, 'feature-test')
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.notification_center).to receive(:send_notifications).once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'all-feature-variables', 'test_user', {},
            feature_enabled: true,
            feature_key: 'all_variables_feature',
            source: 'feature-test',
            variable_values: {
              'json_variable' => {'val' => 'default json'},
              'string_variable' => 'default string',
              'boolean_variable' => false,
              'double_variable' => 1.99,
              'integer_variable' => 10
            },
            source_info: {
              experiment_key: 'test-exp',
              variation_key: '177775'
            }
          )

          expect(project_instance.get_all_feature_variables('all_variables_feature', user_id, user_attributes))
            .to eq(
              'json_variable' => {'val' => 'default json'},
              'string_variable' => 'default string',
              'boolean_variable' => false,
              'double_variable' => 1.99,
              'integer_variable' => 10
            )
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::DEBUG,
                                                     "Variable value is not defined. Returning the default variable value '{ \"val\": \"default json\" }' for variable 'json_variable'."
                                                   )
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::DEBUG,
                                                     "Variable value is not defined. Returning the default variable value '{ \"val\": \"default json\" }' for variable 'json_variable'."
                                                   )
        end
      end

      describe 'and a variable usage instance is found' do
        it 'should return the variable value for the variation for the user is bucketed into' do
          experiment_to_return = project_config.experiment_key_map['test_experiment_with_feature_rollout']
          variation_to_return = {
            'id' => '12345678',
            'featureEnabled' => true
          }
          variation_id_to_variable_usage_map = {
            '12345678' => {
              '155558891' => {
                'value' => '{ "val": "feature enabled" }'
              },
              '155558892' => {
                'value' => 'feature enabled'
              },
              '155558893' => {
                'value' => 'true'
              },
              '155558894' => {
                'value' => '14.99'
              },
              '155558895' => {
                'value' => '99'
              }
            }
          }

          decision_to_return = {
            'experiment' => experiment_to_return,
            'variation' => variation_to_return
          }
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
          allow(project_config).to receive(:variation_id_to_variable_usage_map).and_return(variation_id_to_variable_usage_map)

          expect(project_instance.notification_center).to receive(:send_notifications).once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'all-feature-variables', 'test_user', {},
            feature_enabled: true,
            feature_key: 'all_variables_feature',
            source: 'rollout',
            variable_values: {
              'json_variable' => {'val' => 'feature enabled'},
              'string_variable' => 'feature enabled',
              'boolean_variable' => true,
              'double_variable' => 14.99,
              'integer_variable' => 99
            },
            source_info: {}
          )

          expect(project_instance.get_all_feature_variables('all_variables_feature', user_id, user_attributes))
            .to eq(
              'json_variable' => {'val' => 'feature enabled'},
              'string_variable' => 'feature enabled',
              'boolean_variable' => true,
              'double_variable' => 14.99,
              'integer_variable' => 99
            )

          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value '{ \"val\": \"feature enabled\" }' for variable 'json_variable' of feature flag 'all_variables_feature'."
                                                   )
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value 'feature enabled' for variable 'string_variable' of feature flag 'all_variables_feature'."
                                                   )
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value 'true' for variable 'boolean_variable' of feature flag 'all_variables_feature'."
                                                   )
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value '14.99' for variable 'double_variable' of feature flag 'all_variables_feature'."
                                                   )
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value '99' for variable 'integer_variable' of feature flag 'all_variables_feature'."
                                                   )
        end
      end
    end

    describe 'when the feature flag is not enabled for the user' do
      it 'should return the default variable value' do
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(nil)

        expect(project_instance.notification_center).to receive(:send_notifications).once.with(
          Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
          'all-feature-variables', 'test_user', {},
          feature_enabled: false,
          feature_key: 'all_variables_feature',
          source: 'rollout',
          variable_values: {
            'json_variable' => {'val' => 'default json'},
            'string_variable' => 'default string',
            'boolean_variable' => false,
            'double_variable' => 1.99,
            'integer_variable' => 10
          },
          source_info: {}
        )

        expect(project_instance.get_all_feature_variables('all_variables_feature', user_id, user_attributes))
          .to eq(
            'json_variable' => {'val' => 'default json'},
            'string_variable' => 'default string',
            'boolean_variable' => false,
            'double_variable' => 1.99,
            'integer_variable' => 10
          )

        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::INFO,
                                                   "User 'test_user' was not bucketed into experiment or rollout for feature flag 'all_variables_feature'. Returning the default variable value '{ \"val\": \"default json\" }'."
                                                 )
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::INFO,
                                                   "User 'test_user' was not bucketed into experiment or rollout for feature flag 'all_variables_feature'. Returning the default variable value 'default string'."
                                                 )
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::INFO,
                                                   "User 'test_user' was not bucketed into experiment or rollout for feature flag 'all_variables_feature'. Returning the default variable value 'false'."
                                                 )
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::INFO,
                                                   "User 'test_user' was not bucketed into experiment or rollout for feature flag 'all_variables_feature'. Returning the default variable value '1.99'."
                                                 )
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::INFO,
                                                   "User 'test_user' was not bucketed into experiment or rollout for feature flag 'all_variables_feature'. Returning the default variable value '10'."
                                                 )
      end
    end

    describe 'when the specified feature flag is invalid' do
      it 'should log an error message and return nil' do
        expect(project_instance.get_all_feature_variables('totally_invalid_feature_key', user_id, user_attributes))
          .to eq(nil)
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
  end

  describe '#get_feature_variable' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should return nil when called with invalid project config' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      expect(invalid_project.get_feature_variable('string_single_variable_feature', 'string_variable', user_id, user_attributes))
        .to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Optimizely instance is not valid. Failing 'get_feature_variable'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.get_feature_variable('string_single_variable_feature', 'string_variable', user_id, user_attributes)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'get_feature_variable'."
      )
    end

    describe 'when the feature flag is enabled for the user' do
      describe 'and a variable usage instance is not found' do
        it 'should return the default variable value!!!' do
          variation_to_return = project_config.rollout_id_map['166661']['experiments'][0]['variations'][0]
          decision_to_return = {
            'experiment' => nil,
            'variation' => variation_to_return
          }
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.get_feature_variable('string_single_variable_feature', 'string_variable', user_id, user_attributes))
            .to eq('wingardium leviosa')
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::DEBUG,
                                                     "Variable value is not defined. Returning the default variable value 'wingardium leviosa' for variable 'string_variable'."
                                                   )
        end
      end

      describe 'and a variable usage instance is found' do
        it 'should return the string variable value for the variation for the user is bucketed into' do
          experiment_to_return = project_config.experiment_key_map['test_experiment_with_feature_rollout']
          variation_to_return = experiment_to_return['variations'][0]
          decision_to_return = {
            'experiment' => experiment_to_return,
            'variation' => variation_to_return
          }
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.get_feature_variable('string_single_variable_feature', 'string_variable', user_id, user_attributes))
            .to eq('cta_1')

          expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value 'cta_1' for variable 'string_variable' of feature flag 'string_single_variable_feature'."
                                                   )
        end

        it 'should return the boolean variable value for the variation for the user is bucketed into' do
          boolean_feature = project_config.feature_flag_key_map['boolean_single_variable_feature']
          rollout = project_config.rollout_id_map[boolean_feature['rolloutId']]
          variation_to_return = rollout['experiments'][0]['variations'][0]
          decision_to_return = {
            'experiment' => nil,
            'variation' => variation_to_return
          }
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.get_feature_variable('boolean_single_variable_feature', 'boolean_variable', user_id, user_attributes))
            .to eq(true)

          expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value 'true' for variable 'boolean_variable' of feature flag 'boolean_single_variable_feature'."
                                                   )
        end

        it 'should return the double variable value for the variation for the user is bucketed into' do
          double_feature = project_config.feature_flag_key_map['double_single_variable_feature']
          experiment_to_return = project_config.experiment_id_map[double_feature['experimentIds'][0]]
          variation_to_return = experiment_to_return['variations'][0]
          decision_to_return = {
            'experiment' => experiment_to_return,
            'variation' => variation_to_return
          }

          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.get_feature_variable('double_single_variable_feature', 'double_variable', user_id, user_attributes))
            .to eq(42.42)

          expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value '42.42' for variable 'double_variable' of feature flag 'double_single_variable_feature'."
                                                   )
        end

        it 'should return the integer variable value for the variation for the user is bucketed into' do
          integer_feature = project_config.feature_flag_key_map['integer_single_variable_feature']
          experiment_to_return = project_config.experiment_id_map[integer_feature['experimentIds'][0]]
          variation_to_return = experiment_to_return['variations'][0]
          decision_to_return = {
            'experiment' => experiment_to_return,
            'variation' => variation_to_return
          }

          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

          expect(project_instance.get_feature_variable('integer_single_variable_feature', 'integer_variable', user_id, user_attributes))
            .to eq(42)

          expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
          expect(spy_logger).to have_received(:log).once
                                                   .with(
                                                     Logger::INFO,
                                                     "Got variable value '42' for variable 'integer_variable' of feature flag 'integer_single_variable_feature'."
                                                   )
        end
      end
    end

    describe 'when the feature flag is not enabled for the user' do
      it 'should return the default variable value' do
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(nil)

        expect(project_instance.get_feature_variable('string_single_variable_feature', 'string_variable', user_id, user_attributes))
          .to eq('wingardium leviosa')
        expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::INFO,
                                                   "User 'test_user' was not bucketed into experiment or rollout for feature flag 'string_single_variable_feature'. Returning the default variable value 'wingardium leviosa'."
                                                 )
      end
    end

    describe 'when the specified feature flag is invalid' do
      it 'should log an error message and return nil' do
        expect(project_instance.get_feature_variable('totally_invalid_feature_key', 'string_variable', user_id, user_attributes))
          .to eq(nil)
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
        expect(project_instance.get_feature_variable('string_single_variable_feature', 'invalid_string_variable', user_id, user_attributes))
          .to eq(nil)
        expect(spy_logger).to have_received(:log).once
                                                 .with(
                                                   Logger::ERROR,
                                                   "No feature variable was found for key 'invalid_string_variable' in feature flag 'string_single_variable_feature'."
                                                 )
      end
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
        @project_typed_audience_instance = Optimizely::Project.new(datafile: JSON.dump(OptimizelySpec::CONFIG_DICT_WITH_TYPED_AUDIENCES), logger: spy_logger, error_handler: error_handler)
      end
      after(:example) do
        @project_typed_audience_instance.close
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

  describe '#get_feature_variable_for_type listener' do
    user_id = 'test_user'
    user_attributes = {}

    it 'should call decision listener with default variable type and value, when user in experiment and feature is not enabled' do
      integer_feature = project_config.feature_flag_key_map['integer_single_variable_feature']
      experiment_to_return = project_config.experiment_id_map[integer_feature['experimentIds'][0]]
      variation_to_return = experiment_to_return['variations'][0]
      variation_to_return['featureEnabled'] = false
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
      )

      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      # DECISION listener called when the user is in experiment with variation feature off.
      expect(project_instance.notification_center).to receive(:send_notifications).once.with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        'feature-variable', 'test_user', {},
        feature_key: 'integer_single_variable_feature',
        feature_enabled: false,
        source: 'feature-test',
        variable_key: 'integer_variable',
        variable_type: 'integer',
        variable_value: 7,
        source_info: {
          experiment_key: 'test_experiment_integer_feature',
          variation_key: 'control'
        }
      )

      expect(project_instance.send(
               :get_feature_variable_for_type,
               'integer_single_variable_feature',
               'integer_variable',
               'integer',
               user_id,
               nil
             )).to eq(7)

      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Feature 'integer_single_variable_feature' is not enabled for user 'test_user'. Returning the default variable value '7'."
      )
    end

    it 'should call decision listener with correct variable type and value, when user in experiment and feature is enabled' do
      integer_feature = project_config.feature_flag_key_map['integer_single_variable_feature']
      experiment_to_return = project_config.experiment_id_map[integer_feature['experimentIds'][0]]
      variation_to_return = experiment_to_return['variations'][0]
      variation_to_return['featureEnabled'] = true
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
      )

      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      # DECISION listener called when the user is in experiment with variation feature on.
      expect(project_instance.notification_center).to receive(:send_notifications).once.with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        'feature-variable', 'test_user', {'browser_type' => 'firefox'},
        feature_key: 'integer_single_variable_feature',
        feature_enabled: true,
        source: 'feature-test',
        variable_key: 'integer_variable',
        variable_type: 'integer',
        variable_value: 42,
        source_info: {
          experiment_key: 'test_experiment_integer_feature',
          variation_key: 'control'
        }
      )

      expect(project_instance.send(
               :get_feature_variable_for_type,
               'integer_single_variable_feature',
               'integer_variable',
               'integer',
               user_id,
               'browser_type' => 'firefox'
             )).to eq(42)
    end

    it 'should call decision listener with correct variable type and value, when user in rollout and feature is enabled' do
      experiment_to_return = config_body['rollouts'][0]['experiments'][0]

      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
      )

      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      # DECISION listener called when the user is in rollout with variation feature on.
      expect(variation_to_return['featureEnabled']).to be true
      expect(project_instance.notification_center).to receive(:send_notifications).once.with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        'feature-variable', 'test_user', {},
        feature_key: 'boolean_single_variable_feature',
        feature_enabled: true,
        source: 'rollout',
        variable_key: 'boolean_variable',
        variable_type: 'boolean',
        variable_value: true,
        source_info: {}
      )

      expect(project_instance.send(
               :get_feature_variable_for_type,
               'boolean_single_variable_feature',
               'boolean_variable',
               'boolean',
               user_id,
               user_attributes
             )).to eq(true)
    end

    it 'should call listener with default variable type and value, when user in rollout and feature is not enabled' do
      experiment_to_return = config_body['rollouts'][0]['experiments'][1]
      variation_to_return = experiment_to_return['variations'][0]
      decision_to_return = Optimizely::DecisionService::Decision.new(
        experiment_to_return,
        variation_to_return,
        Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
      )
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)

      # DECISION listener called when the user is in rollout with variation feature on.
      expect(variation_to_return['featureEnabled']).to be false
      expect(project_instance.notification_center).to receive(:send_notifications).once.with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        'feature-variable', 'test_user', {},
        feature_key: 'boolean_single_variable_feature',
        feature_enabled: false,
        source: 'rollout',
        variable_key: 'boolean_variable',
        variable_type: 'boolean',
        variable_value: true,
        source_info: {}
      )

      expect(project_instance.send(
               :get_feature_variable_for_type,
               'boolean_single_variable_feature',
               'boolean_variable',
               'boolean',
               user_id,
               user_attributes
             )).to eq(true)

      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        "Feature 'boolean_single_variable_feature' is not enabled for user 'test_user'. Returning the default variable value 'true'."
      )
    end

    it 'should call listener with default variable type and value, when user neither in experiment nor in rollout' do
      allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(nil)

      expect(project_instance.notification_center).to receive(:send_notifications).once.with(
        Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
        'feature-variable', 'test_user', {},
        feature_key: 'integer_single_variable_feature',
        feature_enabled: false,
        source: 'rollout',
        variable_key: 'integer_variable',
        variable_type: 'integer',
        variable_value: 7,
        source_info: {}
      )
      expect(project_instance.send(
               :get_feature_variable_for_type,
               'integer_single_variable_feature',
               'integer_variable',
               'integer',
               user_id,
               user_attributes
             )).to eq(7)
    end
  end

  describe 'when forced variation is used' do
    # setForcedVariation on a paused experiment and then call getVariation.
    it 'should return null when getVariation is called on a paused experiment after setForcedVariation' do
      project_instance.set_forced_variation('test_experiment_not_started', 'test_user', 'control_not_started')
      expect(project_instance.get_variation('test_experiment_not_started', 'test_user')).to eq(nil)
    end

    # setForcedVariation on a running experiment and then call getVariation.
    it 'should return expected variation id  when getVariation is called on a running experiment after setForcedVariation' do
      project_instance.set_forced_variation('test_experiment', 'test_user', 'variation')
      expect(project_instance.get_variation('test_experiment', 'test_user')).to eq('variation')
    end

    # setForcedVariation on a whitelisted user on the variation that they are not forced into and then call getVariation on the user.
    it 'should return expected forced variation id  when getVariation is called on a running experiment after setForcedVariation is called on a whitelisted user' do
      project_instance.set_forced_variation('test_experiment', 'forced_user1', 'variation')
      expect(project_instance.get_variation('test_experiment', 'forced_user1')).to eq('variation')
    end

    # setForcedVariation on a running experiment with a previously set variation (different from the one set by setForcedVariation) and then call getVariation.
    it 'should return latest set variation when different variations are set on the same experiment' do
      project_instance.set_forced_variation('test_experiment', 'test_user', 'control')
      project_instance.set_forced_variation('test_experiment', 'test_user', 'variation')
      expect(project_instance.get_variation('test_experiment', 'test_user')).to eq('variation')
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
      expect(project_instance.get_forced_variation('test_experiment', 'test_user')).to eq('variation')
    end
  end

  describe '#set_forced_variation' do
    user_id = 'test_user'
    valid_experiment = {id: '111127', key: 'test_experiment'}
    valid_variation = {id: '111128', key: 'control'}

    it 'should log an error when called with an invalid Project object' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      invalid_project.set_forced_variation(valid_experiment[:key], user_id, valid_variation[:key])
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Optimizely instance is not valid. Failing 'set_forced_variation'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.set_forced_variation(valid_experiment[:key], user_id, valid_variation[:key])).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'set_forced_variation'."
      )
    end

    it 'should call inputs_valid? with the proper arguments' do
      expect(Optimizely::Helpers::Validator).to receive(:inputs_valid?).with(
        {
          experiment_key: valid_experiment[:key],
          user_id: user_id,
          variation_key: valid_variation[:key]
        }, spy_logger, Logger::ERROR
      )
      project_instance.set_forced_variation(valid_experiment[:key], user_id, valid_variation[:key])
    end

    it 'should return false and log a message when an invalid user_id is passed' do
      expect(project_instance.set_forced_variation(valid_experiment[:key], nil, valid_variation[:key])).to be false
      expect(project_instance.set_forced_variation(valid_experiment[:key], 5, valid_variation[:key])).to be false
      expect(project_instance.set_forced_variation(valid_experiment[:key], 5.5, valid_variation[:key])).to be false
      expect(project_instance.set_forced_variation(valid_experiment[:key], true, valid_variation[:key])).to be false
      expect(project_instance.set_forced_variation(valid_experiment[:key], {}, valid_variation[:key])).to be false
      expect(project_instance.set_forced_variation(valid_experiment[:key], [], valid_variation[:key])).to be false
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'User ID is invalid').exactly(6).times
    end
    # Invalid Experiment key
    it 'should return false when experiment_key is passed as invalid' do
      expect(project_instance.set_forced_variation(nil, user_id, valid_variation[:key])).to eq(false)
      expect(project_instance.set_forced_variation('', user_id, valid_variation[:key])).to eq(false)
      expect(spy_logger).to have_received(:log).twice.with(Logger::ERROR,
                                                           'Experiment key is invalid')
    end
    # Variation key is an empty string
    it 'should persist forced variation mapping, log a message and return false when variation_key is passed as empty string' do
      expect(project_instance.set_forced_variation(valid_experiment[:key], user_id, '')).to eq(false)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR,
                                                     'Variation key is invalid')
      expect(project_instance.get_forced_variation(valid_experiment[:key], user_id)).to eq(nil)
    end
  end

  describe '#get_forced_variation' do
    user_id = 'test_user'
    valid_experiment = {id: '111127', key: 'test_experiment'}

    it 'should log an error when called with an invalid Project object' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      invalid_project.get_forced_variation(valid_experiment[:key], user_id)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Provided datafile is in an invalid format.')
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, "Optimizely instance is not valid. Failing 'get_forced_variation'.")
      invalid_project.close
    end

    it 'should return nil and log an error when Config Manager returns nil config' do
      allow(project_instance.config_manager).to receive(:config).and_return(nil)
      expect(project_instance.get_forced_variation(valid_experiment[:key], user_id)).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        "Optimizely instance is not valid. Failing 'get_forced_variation'."
      )
    end

    it 'should call inputs_valid? with the proper arguments' do
      expect(Optimizely::Helpers::Validator).to receive(:inputs_valid?).with(
        {
          experiment_key: valid_experiment[:key],
          user_id: user_id
        }, spy_logger, Logger::ERROR
      )
      project_instance.get_forced_variation(valid_experiment[:key], user_id)
    end

    it 'should return nil and log a message when invalid user_id is passed' do
      expect(project_instance.get_forced_variation(valid_experiment[:key], nil)).to eq(nil)
      expect(project_instance.get_forced_variation(valid_experiment[:key], 5)).to eq(nil)
      expect(project_instance.get_forced_variation(valid_experiment[:key], 5.5)).to eq(nil)
      expect(project_instance.get_forced_variation(valid_experiment[:key], true)).to eq(nil)
      expect(project_instance.get_forced_variation(valid_experiment[:key], {})).to eq(nil)
      expect(project_instance.get_forced_variation(valid_experiment[:key], [])).to eq(nil)
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'User ID is invalid').exactly(6).times
    end
    # Experiment key is invalid
    it 'should return nil and log a message when experiment_key is passed as invalid' do
      expect(project_instance.get_forced_variation(nil, user_id)).to eq(nil)
      expect(project_instance.get_forced_variation('', user_id)).to eq(nil)
      expect(spy_logger).to have_received(:log).twice.with(Logger::ERROR,
                                                           'Experiment key is invalid')
    end
  end

  describe '#is_valid' do
    it 'should return false when called with an invalid datafile' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      expect(invalid_project.is_valid).to be false
      invalid_project.close
    end
  end

  describe '.close' do
    before(:example) do
      stub_request(:post, impression_log_url)
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .with(
          headers: {
            'Content-Type' => 'application/json'
          }
        )
        .to_return(status: 200, body: config_body_JSON, headers: {})
    end

    it 'should stop config manager and event processor when optimizely close is called' do
      config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: sdk_key,
        start_by_default: true
      )

      event_processor = Optimizely::BatchEventProcessor.new(event_dispatcher: Optimizely::EventDispatcher.new)

      Optimizely::Project.new(datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler).close

      project_instance = Optimizely::Project.new(skip_json_validation: true, config_manager: config_manager, event_processor: event_processor)

      expect(config_manager.stopped).to be false
      expect(event_processor.started).to be false
      event_processor.start!
      expect(event_processor.started).to be true

      project_instance.close

      expect(config_manager.stopped).to be true
      expect(event_processor.started).to be false
      expect(project_instance.stopped).to be true
    end

    it 'should stop invalid object' do
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: sdk_key
      )

      project_instance = Optimizely::Project.new(
        logger: spy_logger, error_handler: error_handler,
        config_manager: http_project_config_manager
      )

      project_instance.close
      expect(project_instance.is_valid).to be false
    end

    it 'shoud return optimizely as invalid for an API when close is called' do
      http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: sdk_key
      )

      project_instance = Optimizely::Project.new(
        datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler,
        config_manager: http_project_config_manager
      )

      sleep 0.1 until http_project_config_manager.ready?

      expect(project_instance.activate('test_experiment', 'test_user')).not_to eq(nil)
      expect(project_instance.is_valid).to be true

      project_instance.close

      expect(project_instance.is_valid).to be false
      expect(project_instance.activate('test_experiment', 'test_user')).to eq(nil)
    end

    it 'should not raise exception for static config manager' do
      static_project_config_manager = Optimizely::StaticProjectConfigManager.new(
        config_body_JSON, spy_logger, error_handler, false
      )

      project_instance = Optimizely::Project.new(
        logger: spy_logger, error_handler: error_handler,
        config_manager: static_project_config_manager
      )

      project_instance.close
      expect(project_instance.stopped).to be true
    end

    it 'should not raise exception in any API using static config manager' do
      static_project_config_manager = Optimizely::StaticProjectConfigManager.new(
        nil, spy_logger, error_handler, false
      )

      project_instance = Optimizely::Project.new(
        datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler,
        config_manager: static_project_config_manager
      )

      project_instance.close

      expect(project_instance.stopped).to be true
      expect(project_instance.activate('checkout_flow_experiment', 'test_user')).to eq(nil)
      expect(project_instance.get_variation('checkout_flow_experiment', 'test_user')).to eq(nil)
      expect(project_instance.track('test_event', 'test_user')).to eq(nil)
      expect(project_instance.is_feature_enabled('boolean_single_variable_feature', 'test_user')).to be false
      expect(project_instance.get_enabled_features('test_user')).to be_empty
      expect(project_instance.set_forced_variation('test_experiment', 'test', 'variation')).to eq(nil)
      expect(project_instance.get_forced_variation('test_experiment', 'test_user')).to eq(nil)
      expect(project_instance.get_feature_variable('integer_single_variable_feature', 'integer_variable', 'test_user', nil))
        .to eq(nil)
      expect(project_instance.get_feature_variable_string('string_single_variable_feature', 'string_variable', 'test_user', nil))
        .to eq(nil)
      expect(project_instance.get_feature_variable_boolean('boolean_single_variable_feature', 'boolean_variable', 'test_user', nil))
        .to eq(nil)
      expect(project_instance.get_feature_variable_double('double_single_variable_feature', 'double_variable', 'test_user', nil))
        .to eq(nil)
      expect(project_instance.get_feature_variable_integer('integer_single_variable_feature', 'integer_variable', 'test_user', nil))
        .to eq(nil)
    end
  end

  describe '#decide' do
    describe 'should return empty decision object with correct reason when sdk is not ready' do
      it 'when sdk is not ready' do
        invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
        user_context = project_instance.create_user_context('user1')
        decision = invalid_project.decide(user_context, 'dummy_flag')
        expect(decision.as_json).to eq(
          enabled: false,
          flag_key: 'dummy_flag',
          reasons: ['Optimizely SDK not configured properly yet.'],
          rule_key: nil,
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {},
          variation_key: nil
        )
        invalid_project.close
      end

      it 'when flag key is invalid' do
        user_context = project_instance.create_user_context('user1')
        decision = project_instance.decide(user_context, 123)
        expect(decision.as_json).to eq(
          enabled: false,
          flag_key: 123,
          reasons: ['No flag was found for key "123".'],
          rule_key: nil,
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {},
          variation_key: nil
        )
      end

      it 'when flag key is not available' do
        user_context = project_instance.create_user_context('user1')
        decision = project_instance.decide(user_context, 'not_found_key')
        expect(decision.as_json).to eq(
          enabled: false,
          flag_key: 'not_found_key',
          reasons: ['No flag was found for key "not_found_key".'],
          rule_key: nil,
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {},
          variation_key: nil
        )
      end
    end

    describe 'should return correct decision object' do
      it 'when user is bucketed into a feature experiment' do
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][0]
        expect(project_instance.notification_center).to receive(:send_notifications)
          .once.with(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args)
        expect(project_instance.notification_center).to receive(:send_notifications)
          .once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'flag',
            'user1',
            {},
            flag_key: 'multi_variate_feature',
            enabled: true,
            variables: {'first_letter' => 'F', 'rest_of_name' => 'red'},
            variation_key: 'Fred',
            rule_key: 'test_experiment_multivariate',
            reasons: [],
            decision_event_dispatched: true
          )
        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        )
        decision_list_to_be_returned = []
        decision_list_to_be_returned << [decision_to_return, []]
        allow(project_instance.decision_service).to receive(:get_variations_for_feature_list).and_return(decision_list_to_be_returned)
        user_context = project_instance.create_user_context('user1')
        decision = project_instance.decide(user_context, 'multi_variate_feature')
        expect(decision.as_json).to include(
          flag_key: 'multi_variate_feature',
          enabled: true,
          reasons: [],
          rule_key: 'test_experiment_multivariate',
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {'first_letter' => 'F', 'rest_of_name' => 'red'},
          variation_key: 'Fred'
        )
      end

      it 'when user is bucketed into a rollout and send_flag_decisions is true' do
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][0]
        allow(Time).to receive(:now).and_return(time_now)
        allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')
        expect(project_instance.notification_center).to receive(:send_notifications)
          .once.with(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args)
        expect(project_instance.notification_center).to receive(:send_notifications)
          .once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'flag',
            'user1',
            {},
            flag_key: 'multi_variate_feature',
            enabled: true,
            variables: {'first_letter' => 'F', 'rest_of_name' => 'red'},
            variation_key: 'Fred',
            rule_key: 'test_experiment_multivariate',
            reasons: [],
            decision_event_dispatched: true
          )
        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
        )
        decision_list_to_be_returned = []
        decision_list_to_be_returned << [decision_to_return, []]
        allow(project_instance.decision_service).to receive(:get_variations_for_feature_list).and_return(decision_list_to_be_returned)
        user_context = project_instance.create_user_context('user1')
        decision = project_instance.decide(user_context, 'multi_variate_feature')

        # wait for batch processing thread to send event
        sleep 0.1 until project_instance.event_processor.event_queue.empty?

        expect(decision.as_json).to include(
          flag_key: 'multi_variate_feature',
          enabled: true,
          reasons: [],
          rule_key: 'test_experiment_multivariate',
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {'first_letter' => 'F', 'rest_of_name' => 'red'},
          variation_key: 'Fred'
        )
        expected_params = {
          account_id: '12001',
          project_id: '111001',
          revision: '42',
          client_name: 'ruby-sdk',
          client_version: Optimizely::VERSION,
          anonymize_ip: false,
          enrich_decisions: true,
          visitors: [{
            snapshots: [{
              events: [{
                entity_id: '4',
                uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
                key: 'campaign_activated',
                timestamp: (time_now.to_f * 1000).to_i
              }],
              decisions: [{
                campaign_id: '4',
                experiment_id: '122230',
                variation_id: '122231',
                metadata: {
                  flag_key: 'multi_variate_feature',
                  rule_key: 'test_experiment_multivariate',
                  rule_type: 'rollout',
                  variation_key: 'Fred',
                  enabled: true
                }
              }]
            }],
            visitor_id: 'user1',
            attributes: [{
              entity_id: '$opt_bot_filtering',
              key: '$opt_bot_filtering',
              type: 'custom',
              value: true
            }]
          }]
        }
        expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, expected_params, post_headers))
      end

      it 'when user is bucketed into a rollout and send_flag_decisions is false' do
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][0]
        expect(project_instance.notification_center).to receive(:send_notifications)
          .once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'flag',
            'user1',
            {},
            flag_key: 'multi_variate_feature',
            enabled: true,
            variables: {'first_letter' => 'F', 'rest_of_name' => 'red'},
            variation_key: 'Fred',
            rule_key: 'test_experiment_multivariate',
            reasons: [],
            decision_event_dispatched: false
          )
        allow(project_config).to receive(:send_flag_decisions).and_return(false)
        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['ROLLOUT']
        )
        decision_list_to_return = [[decision_to_return, []]]
        allow(project_instance.decision_service).to receive(:get_variations_for_feature_list).and_return(decision_list_to_return)
        user_context = project_instance.create_user_context('user1')
        decision = project_instance.decide(user_context, 'multi_variate_feature')
        expect(decision.as_json).to include(
          flag_key: 'multi_variate_feature',
          enabled: true,
          reasons: [],
          rule_key: 'test_experiment_multivariate',
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {'first_letter' => 'F', 'rest_of_name' => 'red'},
          variation_key: 'Fred'
        )
        expect(project_instance.event_dispatcher).to have_received(:dispatch_event).exactly(0).times
      end

      it 'when decision service returns nil and send_flag_decisions is false' do
        expect(project_instance.notification_center).to receive(:send_notifications)
          .once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'flag',
            'user1',
            {},
            flag_key: 'multi_variate_feature',
            enabled: false,
            variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
            variation_key: nil,
            rule_key: nil,
            reasons: [],
            decision_event_dispatched: false
          )
        allow(project_config).to receive(:send_flag_decisions).and_return(false)
        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        decision_to_return = nil
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
        user_context = project_instance.create_user_context('user1')
        decision = project_instance.decide(user_context, 'multi_variate_feature')
        expect(decision.as_json).to include(
          flag_key: 'multi_variate_feature',
          enabled: false,
          reasons: [],
          rule_key: nil,
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
          variation_key: nil
        )
        expect(project_instance.event_dispatcher).to have_received(:dispatch_event).exactly(0).times
      end

      it 'when decision service returns nil and send_flag_decisions is true' do
        allow(Time).to receive(:now).and_return(time_now)
        allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')
        expect(project_instance.notification_center).to receive(:send_notifications)
          .once.with(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args)
        expect(project_instance.notification_center).to receive(:send_notifications)
          .once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'flag',
            'user1',
            {},
            flag_key: 'multi_variate_feature',
            enabled: false,
            variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
            variation_key: nil,
            rule_key: nil,
            reasons: [],
            decision_event_dispatched: true
          )
        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        decision_to_return = nil
        allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
        user_context = project_instance.create_user_context('user1')
        decision = project_instance.decide(user_context, 'multi_variate_feature')

        # wait for batch processing thread to send event
        sleep 0.1 until project_instance.event_processor.event_queue.empty?

        expect(decision.as_json).to include(
          flag_key: 'multi_variate_feature',
          enabled: false,
          reasons: [],
          rule_key: nil,
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
          variation_key: nil
        )
        expected_params = {
          account_id: '12001',
          project_id: '111001',
          revision: '42',
          client_name: 'ruby-sdk',
          client_version: Optimizely::VERSION,
          anonymize_ip: false,
          enrich_decisions: true,
          visitors: [{
            snapshots: [{
              events: [{
                entity_id: '',
                uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
                key: 'campaign_activated',
                timestamp: (time_now.to_f * 1000).to_i
              }],
              decisions: [{
                campaign_id: '',
                experiment_id: '',
                variation_id: '',
                metadata: {
                  flag_key: 'multi_variate_feature',
                  rule_key: '',
                  rule_type: 'rollout',
                  variation_key: '',
                  enabled: false
                }
              }]
            }],
            visitor_id: 'user1',
            attributes: [{
              entity_id: '$opt_bot_filtering',
              key: '$opt_bot_filtering',
              type: 'custom',
              value: true
            }]
          }]
        }
        expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, expected_params, post_headers))
      end
    end

    describe 'decide options' do
      describe 'DISABLE_DECISION_EVENT' do
        it 'should send event when option is not set' do
          experiment_to_return = config_body['experiments'][3]
          variation_to_return = experiment_to_return['variations'][0]
          expect(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
          decision_to_return = Optimizely::DecisionService::Decision.new(
            experiment_to_return,
            variation_to_return,
            Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          )
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
          user_context = project_instance.create_user_context('user1')
          project_instance.decide(user_context, 'multi_variate_feature')
        end

        it 'should not send event when option is set' do
          experiment_to_return = config_body['experiments'][3]
          variation_to_return = experiment_to_return['variations'][0]
          expect(project_instance.event_dispatcher).not_to receive(:dispatch_event).with(instance_of(Optimizely::Event))
          decision_to_return = Optimizely::DecisionService::Decision.new(
            experiment_to_return,
            variation_to_return,
            Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          )
          allow(project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
          user_context = project_instance.create_user_context('user1')
          project_instance.decide(user_context, 'multi_variate_feature', [Optimizely::Decide::OptimizelyDecideOption::DISABLE_DECISION_EVENT])
        end
      end

      describe 'EXCLUDE_VARIABLES' do
        it 'should exclude variables if set' do
          experiment_to_return = config_body['experiments'][3]
          variation_to_return = experiment_to_return['variations'][0]
          decision_to_return = Optimizely::DecisionService::Decision.new(
            experiment_to_return,
            variation_to_return,
            Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          )
          decision_list_to_be_returned = [[decision_to_return, []]]
          allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
          allow(project_instance.decision_service).to receive(:get_variations_for_feature_list).and_return(decision_list_to_be_returned)
          user_context = project_instance.create_user_context('user1')
          decision = project_instance.decide(user_context, 'multi_variate_feature', [Optimizely::Decide::OptimizelyDecideOption::EXCLUDE_VARIABLES])
          expect(decision.as_json).to include(
            flag_key: 'multi_variate_feature',
            enabled: true,
            reasons: [],
            rule_key: 'test_experiment_multivariate',
            user_context: {attributes: {}, user_id: 'user1'},
            variables: {},
            variation_key: 'Fred'
          )
        end

        it 'should include variables if not set' do
          experiment_to_return = config_body['experiments'][3]
          variation_to_return = experiment_to_return['variations'][0]
          decision_to_return = Optimizely::DecisionService::Decision.new(
            experiment_to_return,
            variation_to_return,
            Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
          )
          decision_list_to_return = [[decision_to_return, []]]
          allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
          allow(project_instance.decision_service).to receive(:get_variations_for_feature_list).and_return(decision_list_to_return)
          user_context = project_instance.create_user_context('user1')
          decision = project_instance.decide(user_context, 'multi_variate_feature')
          expect(decision.as_json).to include(
            flag_key: 'multi_variate_feature',
            enabled: true,
            reasons: [],
            rule_key: 'test_experiment_multivariate',
            user_context: {attributes: {}, user_id: 'user1'},
            variables: {'first_letter' => 'F', 'rest_of_name' => 'red'},
            variation_key: 'Fred'
          )
        end
      end

      describe 'INCLUDE_REASONS' do
        it 'should include reasons when the option is set' do
          expect(project_instance.notification_center).to receive(:send_notifications)
            .once.with(
              Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
              'flag',
              'user1',
              {},
              flag_key: 'multi_variate_feature',
              enabled: false,
              variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
              variation_key: nil,
              rule_key: nil,
              reasons: [
                "Starting to evaluate audience '11154' with conditions: [\"and\", [\"or\", [\"or\", {\"name\": \"browser_type\", \"type\": \"custom_attribute\", \"value\": \"firefox\"}]]].",
                "Audience '11154' evaluated to UNKNOWN.",
                "Audiences for experiment 'test_experiment_multivariate' collectively evaluated to FALSE.",
                "User 'user1' does not meet the conditions to be in experiment 'test_experiment_multivariate'.",
                "The user 'user1' is not bucketed into any of the experiments on the feature 'multi_variate_feature'.",
                "Feature flag 'multi_variate_feature' is not used in a rollout."
              ],
              decision_event_dispatched: true
            )
          expect(project_instance.notification_center).to receive(:send_notifications)
            .once.with(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args)
          allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
          user_context = project_instance.create_user_context('user1')
          decision = project_instance.decide(user_context, 'multi_variate_feature', [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS])
          expect(decision.as_json).to include(
            flag_key: 'multi_variate_feature',
            enabled: false,
            reasons: [
              "Starting to evaluate audience '11154' with conditions: [\"and\", [\"or\", [\"or\", {\"name\": \"browser_type\", \"type\": \"custom_attribute\", \"value\": \"firefox\"}]]].",
              "Audience '11154' evaluated to UNKNOWN.",
              "Audiences for experiment 'test_experiment_multivariate' collectively evaluated to FALSE.",
              "User 'user1' does not meet the conditions to be in experiment 'test_experiment_multivariate'.",
              "The user 'user1' is not bucketed into any of the experiments on the feature 'multi_variate_feature'.",
              "Feature flag 'multi_variate_feature' is not used in a rollout."
            ],
            rule_key: nil,
            user_context: {attributes: {}, user_id: 'user1'},
            variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
            variation_key: nil
          )
        end

        it 'should not include reasons when the option is not set' do
          expect(project_instance.notification_center).to receive(:send_notifications)
            .once.with(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args)
          expect(project_instance.notification_center).to receive(:send_notifications)
            .once.with(
              Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
              'flag',
              'user1',
              {},
              flag_key: 'multi_variate_feature',
              enabled: false,
              variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
              variation_key: nil,
              rule_key: nil,
              reasons: [],
              decision_event_dispatched: true
            )
          allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
          user_context = project_instance.create_user_context('user1')
          decision = project_instance.decide(user_context, 'multi_variate_feature')
          expect(decision.as_json).to include(
            flag_key: 'multi_variate_feature',
            enabled: false,
            reasons: [],
            rule_key: nil,
            user_context: {attributes: {}, user_id: 'user1'},
            variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
            variation_key: nil
          )
        end
      end

      it 'should pass on decide options to internal methods' do
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][0]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        )
        decision_list_to_return = [[decision_to_return, []]]
        allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        allow(project_instance.decision_service).to receive(:get_variations_for_feature_list).and_return(decision_list_to_return)
        user_context = project_instance.create_user_context('user1')

        expect(project_instance.decision_service).to receive(:get_variations_for_feature_list)
          .with(anything, anything, anything, []).once
        project_instance.decide(user_context, 'multi_variate_feature')

        expect(project_instance.decision_service).to receive(:get_variations_for_feature_list)
          .with(anything, anything, anything, [Optimizely::Decide::OptimizelyDecideOption::DISABLE_DECISION_EVENT]).once
        project_instance.decide(user_context, 'multi_variate_feature', [Optimizely::Decide::OptimizelyDecideOption::DISABLE_DECISION_EVENT])

        expect(project_instance.decision_service).to receive(:get_variations_for_feature_list)
          .with(anything, anything, anything, [
                  Optimizely::Decide::OptimizelyDecideOption::DISABLE_DECISION_EVENT,
                  Optimizely::Decide::OptimizelyDecideOption::EXCLUDE_VARIABLES,
                  Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE,
                  Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS,
                  Optimizely::Decide::OptimizelyDecideOption::EXCLUDE_VARIABLES
                ]).once
        project_instance
          .decide(user_context, 'multi_variate_feature', [
                    Optimizely::Decide::OptimizelyDecideOption::DISABLE_DECISION_EVENT,
                    Optimizely::Decide::OptimizelyDecideOption::EXCLUDE_VARIABLES,
                    Optimizely::Decide::OptimizelyDecideOption::ENABLED_FLAGS_ONLY,
                    Optimizely::Decide::OptimizelyDecideOption::IGNORE_USER_PROFILE_SERVICE,
                    Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS,
                    Optimizely::Decide::OptimizelyDecideOption::EXCLUDE_VARIABLES
                  ])
      end
    end
  end

  describe '#decide_all' do
    it 'should get empty object when sdk is not ready' do
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      user_context = project_instance.create_user_context('user1')
      decisions = invalid_project.decide_all(user_context)
      expect(decisions).to eq({})
      invalid_project.close
    end

    it 'should get all the decisions' do
      stub_request(:post, impression_log_url)
      user_context = project_instance.create_user_context('user1')
      decisions = project_instance.decide_all(user_context)
      expect(decisions.length).to eq(10)
      expect(decisions['boolean_single_variable_feature'].as_json).to eq(
        enabled: true,
        flag_key: 'boolean_single_variable_feature',
        reasons: [],
        rule_key: '177776',
        user_context: {attributes: {}, user_id: 'user1'},
        variables: {'boolean_variable' => false},
        variation_key: '177778'
      )
      expect(decisions['integer_single_variable_feature'].as_json).to eq(
        enabled: true,
        flag_key: 'integer_single_variable_feature',
        reasons: [],
        rule_key: 'test_experiment_integer_feature',
        user_context: {attributes: {}, user_id: 'user1'},
        variables: {'integer_variable' => 42},
        variation_key: 'control'
      )
    end

    it 'should get only enabled decisions for keys when ENABLED_FLAGS_ONLY is true' do
      stub_request(:post, impression_log_url)
      user_context = project_instance.create_user_context('user1')
      decisions = project_instance.decide_all(user_context, [Optimizely::Decide::OptimizelyDecideOption::ENABLED_FLAGS_ONLY])

      expect(decisions.length).to eq(6)
      expect(decisions['boolean_single_variable_feature'].as_json).to eq(
        enabled: true,
        flag_key: 'boolean_single_variable_feature',
        reasons: [],
        rule_key: '177776',
        user_context: {attributes: {}, user_id: 'user1'},
        variables: {'boolean_variable' => false},
        variation_key: '177778'
      )
      expect(decisions['integer_single_variable_feature'].as_json).to eq(
        enabled: true,
        flag_key: 'integer_single_variable_feature',
        reasons: [],
        rule_key: 'test_experiment_integer_feature',
        user_context: {attributes: {}, user_id: 'user1'},
        variables: {'integer_variable' => 42},
        variation_key: 'control'
      )
    end
  end

  describe '#decide_for_keys' do
    it 'should get empty object when sdk is not ready' do
      keys = %w[
        boolean_single_variable_feature
        integer_single_variable_feature
        boolean_feature
        empty_feature
      ]
      invalid_project = Optimizely::Project.new(datafile: 'invalid', logger: spy_logger)
      user_context = project_instance.create_user_context('user1')
      decisions = invalid_project.decide_for_keys(user_context, keys)
      expect(decisions).to eq({})
      invalid_project.close
    end

    it 'should get all the decisions for keys' do
      keys = %w[
        boolean_single_variable_feature
        integer_single_variable_feature
        boolean_feature
        empty_feature
      ]
      stub_request(:post, impression_log_url)
      user_context = project_instance.create_user_context('user1')
      decisions = project_instance.decide_for_keys(user_context, keys)
      expect(decisions.length).to eq(4)
      expect(decisions['boolean_single_variable_feature'].as_json).to eq(
        enabled: true,
        flag_key: 'boolean_single_variable_feature',
        reasons: [],
        rule_key: '177776',
        user_context: {attributes: {}, user_id: 'user1'},
        variables: {'boolean_variable' => false},
        variation_key: '177778'
      )
      expect(decisions['integer_single_variable_feature'].as_json).to eq(
        enabled: true,
        flag_key: 'integer_single_variable_feature',
        reasons: [],
        rule_key: 'test_experiment_integer_feature',
        user_context: {attributes: {}, user_id: 'user1'},
        variables: {'integer_variable' => 42},
        variation_key: 'control'
      )
    end

    it 'should get only enabled decisions for keys when ENABLED_FLAGS_ONLY is true' do
      keys = %w[
        boolean_single_variable_feature
        integer_single_variable_feature
        boolean_feature
        empty_feature
      ]
      stub_request(:post, impression_log_url)
      user_context = project_instance.create_user_context('user1')
      decisions = project_instance.decide_for_keys(user_context, keys, [Optimizely::Decide::OptimizelyDecideOption::ENABLED_FLAGS_ONLY])
      expect(decisions.length).to eq(2)
      expect(decisions['boolean_single_variable_feature'].as_json).to eq(
        enabled: true,
        flag_key: 'boolean_single_variable_feature',
        reasons: [],
        rule_key: '177776',
        user_context: {attributes: {}, user_id: 'user1'},
        variables: {'boolean_variable' => false},
        variation_key: '177778'
      )
      expect(decisions['integer_single_variable_feature'].as_json).to eq(
        enabled: true,
        flag_key: 'integer_single_variable_feature',
        reasons: [],
        rule_key: 'test_experiment_integer_feature',
        user_context: {attributes: {}, user_id: 'user1'},
        variables: {'integer_variable' => 42},
        variation_key: 'control'
      )
    end

    it 'should get only enabled decisions for keys when ENABLED_FLAGS_ONLY is true in default_decide_options' do
      custom_project_instance = Optimizely::Project.new(
        datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler,
        default_decide_options: [Optimizely::Decide::OptimizelyDecideOption::ENABLED_FLAGS_ONLY]
      )
      keys = %w[
        boolean_single_variable_feature
        integer_single_variable_feature
        boolean_feature
        empty_feature
      ]
      stub_request(:post, impression_log_url)
      user_context = custom_project_instance.create_user_context('user1')
      decisions = custom_project_instance.decide_for_keys(user_context, keys)
      expect(decisions.length).to eq(2)
      expect(decisions['boolean_single_variable_feature'].as_json).to eq(
        enabled: true,
        flag_key: 'boolean_single_variable_feature',
        reasons: [],
        rule_key: '177776',
        user_context: {attributes: {}, user_id: 'user1'},
        variables: {'boolean_variable' => false},
        variation_key: '177778'
      )
      expect(decisions['integer_single_variable_feature'].as_json).to eq(
        enabled: true,
        flag_key: 'integer_single_variable_feature',
        reasons: [],
        rule_key: 'test_experiment_integer_feature',
        user_context: {attributes: {}, user_id: 'user1'},
        variables: {'integer_variable' => 42},
        variation_key: 'control'
      )
      custom_project_instance.close
    end
  end

  describe 'default_decide_options' do
    describe 'EXCLUDE_VARIABLES' do
      it 'should include variables when the option is not set in default_decide_options' do
        custom_project_instance = Optimizely::Project.new(datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler)
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][0]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        )
        allow(custom_project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        allow(custom_project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
        user_context = custom_project_instance.create_user_context('user1')
        decision = custom_project_instance.decide(user_context, 'multi_variate_feature')
        expect(decision.as_json).to include(
          flag_key: 'multi_variate_feature',
          enabled: true,
          reasons: [],
          rule_key: 'test_experiment_multivariate',
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {'first_letter' => 'F', 'rest_of_name' => 'red'},
          variation_key: 'Fred'
        )
        custom_project_instance.close
      end

      it 'should exclude variables when the option is set in default_decide_options' do
        custom_project_instance = Optimizely::Project.new(
          datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler,
          default_decide_options: [Optimizely::Decide::OptimizelyDecideOption::EXCLUDE_VARIABLES]
        )
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][0]
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        )
        allow(custom_project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        allow(custom_project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
        user_context = custom_project_instance.create_user_context('user1')
        decision = custom_project_instance.decide(user_context, 'multi_variate_feature')
        expect(decision.as_json).to include(
          flag_key: 'multi_variate_feature',
          enabled: true,
          reasons: [],
          rule_key: 'test_experiment_multivariate',
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {},
          variation_key: 'Fred'
        )
        custom_project_instance.close
      end
    end

    describe 'INCLUDE_REASONS' do
      it 'should include reasons when the option is set in default_decide_options' do
        custom_project_instance = Optimizely::Project.new(
          datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler,
          default_decide_options: [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS]
        )
        expect(custom_project_instance.notification_center).to receive(:send_notifications)
          .once.with(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args)
        expect(custom_project_instance.notification_center).to receive(:send_notifications)
          .once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'flag',
            'user1',
            {},
            flag_key: 'multi_variate_feature',
            enabled: false,
            variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
            variation_key: nil,
            rule_key: nil,
            reasons: [
              "Starting to evaluate audience '11154' with conditions: [\"and\", [\"or\", [\"or\", {\"name\": \"browser_type\", \"type\": \"custom_attribute\", \"value\": \"firefox\"}]]].",
              "Audience '11154' evaluated to UNKNOWN.",
              "Audiences for experiment 'test_experiment_multivariate' collectively evaluated to FALSE.",
              "User 'user1' does not meet the conditions to be in experiment 'test_experiment_multivariate'.",
              "The user 'user1' is not bucketed into any of the experiments on the feature 'multi_variate_feature'.",
              "Feature flag 'multi_variate_feature' is not used in a rollout."
            ],
            decision_event_dispatched: true
          )
        allow(custom_project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        user_context = custom_project_instance.create_user_context('user1')
        decision = custom_project_instance.decide(user_context, 'multi_variate_feature')
        expect(decision.as_json).to include(
          flag_key: 'multi_variate_feature',
          enabled: false,
          reasons: [
            "Starting to evaluate audience '11154' with conditions: [\"and\", [\"or\", [\"or\", {\"name\": \"browser_type\", \"type\": \"custom_attribute\", \"value\": \"firefox\"}]]].",
            "Audience '11154' evaluated to UNKNOWN.",
            "Audiences for experiment 'test_experiment_multivariate' collectively evaluated to FALSE.",
            "User 'user1' does not meet the conditions to be in experiment 'test_experiment_multivariate'.",
            "The user 'user1' is not bucketed into any of the experiments on the feature 'multi_variate_feature'.",
            "Feature flag 'multi_variate_feature' is not used in a rollout."
          ],
          rule_key: nil,
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
          variation_key: nil
        )
        custom_project_instance.close
      end

      it 'should not include reasons when the option is not set in default_decide_options' do
        custom_project_instance = Optimizely::Project.new(datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler)
        expect(custom_project_instance.notification_center).to receive(:send_notifications)
          .once.with(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:LOG_EVENT], any_args)
        expect(custom_project_instance.notification_center).to receive(:send_notifications)
          .once.with(
            Optimizely::NotificationCenter::NOTIFICATION_TYPES[:DECISION],
            'flag',
            'user1',
            {},
            flag_key: 'multi_variate_feature',
            enabled: false,
            variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
            variation_key: nil,
            rule_key: nil,
            reasons: [],
            decision_event_dispatched: true
          )
        allow(custom_project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        user_context = custom_project_instance.create_user_context('user1')
        decision = custom_project_instance.decide(user_context, 'multi_variate_feature')
        expect(decision.as_json).to include(
          flag_key: 'multi_variate_feature',
          enabled: false,
          reasons: [],
          rule_key: nil,
          user_context: {attributes: {}, user_id: 'user1'},
          variables: {'first_letter' => 'H', 'rest_of_name' => 'arry'},
          variation_key: nil
        )
        custom_project_instance.close
      end
    end

    describe 'DISABLE_DECISION_EVENT' do
      it 'should send event when option is not set in default_decide_options' do
        custom_project_instance = Optimizely::Project.new(datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler)
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][0]
        expect(custom_project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        )
        allow(custom_project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
        user_context = custom_project_instance.create_user_context('user1')
        custom_project_instance.decide(user_context, 'multi_variate_feature')
        custom_project_instance.close
      end

      it 'should not send event when option is set in default_decide_options' do
        custom_project_instance = Optimizely::Project.new(
          datafile: config_body_JSON, logger: spy_logger, error_handler: error_handler,
          default_decide_options: [Optimizely::Decide::OptimizelyDecideOption::DISABLE_DECISION_EVENT]
        )
        experiment_to_return = config_body['experiments'][3]
        variation_to_return = experiment_to_return['variations'][0]
        expect(custom_project_instance.event_dispatcher).not_to receive(:dispatch_event).with(instance_of(Optimizely::Event))
        decision_to_return = Optimizely::DecisionService::Decision.new(
          experiment_to_return,
          variation_to_return,
          Optimizely::DecisionService::DECISION_SOURCES['FEATURE_TEST']
        )
        allow(custom_project_instance.decision_service).to receive(:get_variation_for_feature).and_return(decision_to_return)
        user_context = custom_project_instance.create_user_context('user1')
        custom_project_instance.decide(user_context, 'multi_variate_feature')
        custom_project_instance.close
      end
    end
  end

  describe 'sdk_settings' do
    it 'should log info when disabled' do
      project_instance.close
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(disable_odp: true)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      expect(project.odp_manager.instance_variable_get('@event_manager')).to be_nil
      expect(project.odp_manager.instance_variable_get('@segment_manager')).to be_nil
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, 'ODP is not enabled.')
    end

    it 'should accept zero for flush interval' do
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(odp_event_flush_interval: 0)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      event_manager = project.odp_manager.instance_variable_get('@event_manager')
      expect(event_manager.instance_variable_get('@flush_interval')).to eq 0
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should use default for flush interval when nil' do
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(odp_event_flush_interval: nil)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      event_manager = project.odp_manager.instance_variable_get('@event_manager')
      expect(event_manager.instance_variable_get('@flush_interval')).to eq 1
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should accept cache_size' do
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)

      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(segments_cache_size: 5)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      segment_manager = project.odp_manager.instance_variable_get('@segment_manager')
      expect(segment_manager.instance_variable_get('@segments_cache').capacity).to eq 5
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should accept cache_timeout' do
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(segments_cache_timeout_in_secs: 5)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      segment_manager = project.odp_manager.instance_variable_get('@segment_manager')
      expect(segment_manager.instance_variable_get('@segments_cache').timeout).to eq 5
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should accept cache_size and cache_timeout' do
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(segments_cache_size: 10, segments_cache_timeout_in_secs: 5)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      segment_manager = project.odp_manager.instance_variable_get('@segment_manager')
      segments_cache = segment_manager.instance_variable_get('@segments_cache')
      expect(segments_cache.capacity).to eq 10
      expect(segments_cache.timeout).to eq 5
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should use default cache_size and cache_timeout when not provided' do
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      segment_manager = project.odp_manager.instance_variable_get('@segment_manager')
      segments_cache = segment_manager.instance_variable_get('@segments_cache')
      expect(segments_cache.capacity).to eq 10_000
      expect(segments_cache.timeout).to eq 600
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should accept zero cache_size and cache_timeout' do
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(segments_cache_size: 0, segments_cache_timeout_in_secs: 0)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      segment_manager = project.odp_manager.instance_variable_get('@segment_manager')
      segments_cache = segment_manager.instance_variable_get('@segments_cache')
      expect(segments_cache.capacity).to eq 0
      expect(segments_cache.timeout).to eq 0
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should accept valid custom cache' do
      class CustomCache # rubocop:disable Lint/ConstantDefinitionInBlock
        def reset; end
        def lookup(key); end
        def save(key, value); end
      end

      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(odp_segments_cache: CustomCache.new)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      segment_manager = project.odp_manager.instance_variable_get('@segment_manager')
      expect(segment_manager.instance_variable_get('@segments_cache')).to be_a CustomCache
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should revert to default cache when custom cache is invalid' do
      class InvalidCustomCache; end # rubocop:disable Lint/ConstantDefinitionInBlock

      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(odp_segments_cache: InvalidCustomCache.new)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)

      segment_manager = project.odp_manager.instance_variable_get('@segment_manager')
      expect(segment_manager.instance_variable_get('@segments_cache')).to be_a Optimizely::LRUCache
      project.close

      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Invalid ODP segments cache, reverting to default.')
    end

    it 'should accept valid custom segment manager' do
      class CustomSegmentManager # rubocop:disable Lint/ConstantDefinitionInBlock
        attr_accessor :odp_config

        def initialize
          @odp_config = nil
        end

        def reset; end
        def fetch_qualified_segments(user_key, user_value, options); end
      end

      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(odp_segment_manager: CustomSegmentManager.new)
      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger, error_handler: error_handler, settings: sdk_settings)
      segment_manager = project.odp_manager.instance_variable_get('@segment_manager')
      expect(segment_manager).to be_a CustomSegmentManager
      project.fetch_qualified_segments(user_id: 'test')
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, 'Stopping ODP event queue.')
    end

    it 'should revert to default segment manager when custom manager is invalid' do
      class InvalidSegmentManager; end # rubocop:disable Lint/ConstantDefinitionInBlock

      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(odp_segment_manager: InvalidSegmentManager.new)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)

      segment_manager = project.odp_manager.instance_variable_get('@segment_manager')
      expect(segment_manager).to be_a Optimizely::OdpSegmentManager
      project.close

      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Invalid ODP segment manager, reverting to default.')
    end

    it 'should accept valid custom event manager' do
      class CustomEventManager # rubocop:disable Lint/ConstantDefinitionInBlock
        attr_accessor :odp_event_timeout

        def send_event(extra_param = nil, action:, type:, identifiers:, data:, other_extra_param: 'great'); end
        def start!(odp_config); end
        def update_config; end
        def stop!; end
        def running?; end
      end

      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(odp_event_manager: CustomEventManager.new)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      event_manager = project.odp_manager.instance_variable_get('@event_manager')
      expect(event_manager).to be_a CustomEventManager
      project.send_odp_event(action: 'test', identifiers: {wow: 'great'})
      project.close

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should revert to default event manager when custom manager is invalid' do
      class InvalidEventManager; end # rubocop:disable Lint/ConstantDefinitionInBlock

      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(odp_event_manager: InvalidEventManager.new)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)

      event_manager = project.odp_manager.instance_variable_get('@event_manager')
      expect(event_manager).to be_a Optimizely::OdpEventManager
      project.close

      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, 'Invalid ODP event manager, reverting to default.')
    end
  end

  describe '#send_odp_event' do
    it 'should send event with StaticProjectConfigManager' do
      stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
      expect(spy_logger).to receive(:log).once.with(Logger::DEBUG, 'ODP event queue: flushing batch size 1.')
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger)
      project.send_odp_event(type: 'wow', action: 'great', identifiers: {amazing: 'fantastic'}, data: {})
      project.close
    end

    it 'should send event with HTTPProjectConfigManager' do
      datafile = OptimizelySpec.deep_clone(config_body_integrations)
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: JSON.dump(datafile))
      stub_request(:post, 'https://api.zaius.com/v3/events').to_return(status: 200)
      expect(spy_logger).to receive(:log).once.with(Logger::DEBUG, 'ODP event queue: flushing batch size 1.')
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      project = Optimizely::Project.new(logger: spy_logger, sdk_key: sdk_key)

      sleep 0.1 until project.odp_manager.instance_variable_get('@event_manager').instance_variable_get('@event_queue').empty?

      project.send_odp_event(type: 'wow', action: 'great', identifiers: {amazing: 'fantastic'}, data: {})
      project.close
    end

    it 'should log error when odp disabled' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'ODP is not enabled.')
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(disable_odp: true)
      custom_project_instance = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger, error_handler: error_handler, settings: sdk_settings)
      custom_project_instance.send_odp_event(type: 'wow', action: 'great', identifiers: {amazing: 'fantastic'}, data: {})
      custom_project_instance.close
    end

    it 'should log error if datafile is invalid' do
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: nil)
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, "Optimizely instance is not valid. Failing 'send_odp_event'.")
      project = Optimizely::Project.new(logger: spy_logger, sdk_key: sdk_key)
      project.send_odp_event(type: 'wow', action: 'great', identifiers: {amazing: 'fantastic'}, data: {})
      project.close
    end

    it 'should log error if odp not enabled with HTTPProjectConfigManager' do
      stub_request(:get, "https://cdn.optimizely.com/datafiles/#{sdk_key}.json")
        .to_return(status: 200, body: config_body_integrations_JSON)
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'ODP is not enabled.')
      sdk_settings = Optimizely::Helpers::OptimizelySdkSettings.new(disable_odp: true)
      project = Optimizely::Project.new(logger: spy_logger, error_handler: error_handler, sdk_key: sdk_key, settings: sdk_settings)
      project.send_odp_event(type: 'wow', action: 'great', identifiers: {amazing: 'fantastic'}, data: {})
      project.close
    end

    it 'should log error with invalid data' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'ODP data is not valid.')
      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger)
      project.send_odp_event(type: 'wow', action: 'great', identifiers: {amazing: 'fantastic'}, data: {'wow': {}})
      project.close
    end

    it 'should log error with empty identifiers' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'ODP events must have at least one key-value pair in identifiers.')
      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger)
      project.send_odp_event(type: 'wow', action: 'great', identifiers: {}, data: {'wow': {}})
      project.close
    end

    it 'should log error with nil identifiers' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'ODP events must have at least one key-value pair in identifiers.')
      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger)
      project.send_odp_event(type: 'wow', action: 'great', identifiers: nil, data: {'wow': {}})
      project.close
    end

    it 'should not send odp events with legacy apis' do
      experiment_key = 'experiment-segment'
      feature_key = 'flag-segment'
      user_id = 'test_user'

      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger)
      allow(project.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      expect(project.odp_manager).not_to receive(:send_event)

      project.activate(experiment_key, user_id)
      project.track('event1', user_id)
      project.get_variation(experiment_key, user_id)
      project.get_all_feature_variables(feature_key, user_id)
      project.is_feature_enabled(feature_key, user_id)

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)

      project.close
    end

    it 'should log error with nil action' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'ODP action is not valid (cannot be empty).')
      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger)
      project.send_odp_event(type: 'wow', action: nil, identifiers: {amazing: 'fantastic'}, data: {})
      project.close
    end

    it 'should log error with empty string action' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, 'ODP action is not valid (cannot be empty).')
      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger)
      project.send_odp_event(type: 'wow', action: '', identifiers: {amazing: 'fantastic'}, data: {})
      project.close
    end

    it 'should use default with nil type' do
      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger)
      expect(project.odp_manager).to receive('send_event').with(type: 'fullstack', action: 'great', identifiers: {amazing: 'fantastic'}, data: {})
      project.send_odp_event(type: nil, action: 'great', identifiers: {amazing: 'fantastic'}, data: {})

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)

      project.close
    end

    it 'should use default with empty string type' do
      project = Optimizely::Project.new(datafile: config_body_integrations_JSON, logger: spy_logger)
      expect(project.odp_manager).to receive('send_event').with(type: 'fullstack', action: 'great', identifiers: {amazing: 'fantastic'}, data: {})
      project.send_odp_event(type: '', action: 'great', identifiers: {amazing: 'fantastic'}, data: {})

      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)

      project.close
    end
  end
end
