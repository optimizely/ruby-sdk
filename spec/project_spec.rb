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
require 'optimizely'
require 'optimizely/audience'
require 'optimizely/helpers/validator'
require 'optimizely/exceptions'
require 'optimizely/version'

describe 'OptimizelyV2' do
  let(:config_body) { OptimizelySpec::V2_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::V2_CONFIG_BODY_JSON }
  let(:config_body_v1_JSON) { OptimizelySpec::V1_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:version) { Optimizely::VERSION }
  let(:impression_log_url) { 'https://logx.optimizely.com/log/decision' }
  let(:conversion_log_url) { 'https://logx.optimizely.com/log/event' }
  let(:project_instance) { Optimizely::Project.new(config_body_JSON, nil, spy_logger, error_handler) }
  let(:time_now) { Time.now }
  let(:post_headers) { { 'Content-Type' => 'application/json' } }

  it 'has a version number' do
    expect(Optimizely::VERSION).not_to be nil
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

    it 'should log an error when provided a datafile that is not JSON and skip_json_validation is true' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')

      Optimizely::Project.new('this is not JSON', nil, nil, nil, true)
    end

    it 'should log an error when provided an invalid JSON datafile and skip_json_validation is true' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format.')

      Optimizely::Project.new('{"foo": "bar"}', nil, nil, nil, true)
    end

    it 'should log an error when provided a datafile of unsupported version' do
      expect_any_instance_of(Optimizely::SimpleLogger).to receive(:log).once.with(Logger::ERROR, 'Provided datafile is an unsupported version. Please use SDK version 1.1.2 or earlier for datafile version 1.')

      Optimizely::Project.new(config_body_v1_JSON, nil, nil, nil, true)
    end
  end

  describe '#activate' do
    before(:example) do
      allow(Time).to receive(:now).and_return(time_now)
    end

    it 'should properly activate a user, invoke Event object with right params, and return variation' do
      params = {
        'projectId' => '111001',
        'accountId' => '12001',
        'visitorId' => 'test_user',
        'userFeatures' => [],
        'clientEngine' => 'ruby-sdk',
        'clientVersion' => version,
        'timestamp' => (time_now.to_f * 1000).to_i,
        'isGlobalHoldback' => false,
        'layerId' => '1',
        'decision' => {
          'variationId' => '111128',
          'experimentId' => '111127',
          'isLayerHoldback' => false,
        }
      }

      allow(project_instance.bucketer).to receive(:bucket).and_return('111128')
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.config).to receive(:get_audience_ids_for_experiment)
                                       .with('test_experiment')
                                       .and_return([])

      stub_request(:post, impression_log_url).with(:query => params)

      expect(project_instance.activate('test_experiment', 'test_user')).to eq('control')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
      expect(project_instance.bucketer).to have_received(:bucket).once
    end

    it 'should properly activate a user, (with attributes provided) when there is an audience match' do
      params = {
        'projectId' => '111001',
        'accountId' => '12001',
        'visitorId' => 'test_user',
        'userFeatures' => [
          {
            'id' => '111094',
            'name' => 'browser_type',
            'type' => 'custom',
            'value' => 'firefox',
            'shouldIndex' => true,
          }
        ],
        'clientEngine' => 'ruby-sdk',
        'clientVersion' => version,
        'timestamp' => (time_now.to_f * 1000).to_i,
        'isGlobalHoldback' => false,
        'layerId' => '3',
        'decision' => {
          'variationId' => '122228',
          'experimentId' => '122227',
          'isLayerHoldback' => false,
        }
      }

      allow(project_instance.bucketer).to receive(:bucket).and_return('122228')
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

      expect(project_instance.activate('test_experiment_with_audience', 'test_user', 'browser_type' => 'firefox'))
        .to eq('control_with_audience')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, impression_log_url, params, post_headers)).once
      expect(project_instance.bucketer).to have_received(:bucket).once
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

    it 'should return nil when user is in no variation' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event)
      allow(project_instance.bucketer).to receive(:bucket).and_return(nil)

      expect(project_instance.activate('test_experiment', 'test_user')).to eq(nil)
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, "Not activating user 'test_user'.")
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
    end

    it 'should log when an impression event is dispatched' do
      params = {
        'projectId' => '111001',
        'accountId' => '12001',
        'visitorId' => 'test_user',
        'userFeatures' => [],
        'clientEngine' => 'ruby-sdk',
        'clientVersion' => version,
        'timestamp' => (time_now.to_f * 1000).to_i,
        'isGlobalHoldback' => false,
        'layerId' => '1',
        'decision' => {
          'variationId' => '111128',
          'experimentId' => '111127',
          'isLayerHoldback' => false,
        }
      }

      allow(project_instance.bucketer).to receive(:bucket).and_return('111128')
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.config).to receive(:get_audience_ids_for_experiment)
                                        .with('test_experiment')
                                        .and_return([])
      project_instance.activate('test_experiment', 'test_user')
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, include("Dispatching impression event to" \
                                                                                " URL #{impression_log_url} with params #{params}"))
    end

    it 'should log when an exception has occurred during dispatching the impression event' do
      allow(project_instance.bucketer).to receive(:bucket).and_return('111128')
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(any_args).and_raise(RuntimeError)
      project_instance.activate('test_experiment', 'test_user')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Unable to dispatch impression event. Error: RuntimeError")
    end

    it 'should raise an exception when called with invalid attributes' do
      expect { project_instance.activate('test_experiment', 'test_user', 'invalid') }
             .to raise_error(Optimizely::InvalidAttributeFormatError)
    end

    it 'should override the audience check if the user is whitelisted to a specific variation' do
      params = {
        'projectId' => '111001',
        'accountId' => '12001',
        'visitorId' => 'forced_audience_user',
        'userFeatures' => [
          {
            'id' => '111094',
            'name' => 'browser_type',
            'type' => 'custom',
            'value' => 'wrong_browser',
            'shouldIndex' => true,
          },
        ],
        'clientEngine' => 'ruby-sdk',
        'clientVersion' => version,
        'timestamp' => (time_now.to_f * 1000).to_i,
        'isGlobalHoldback' => false,
        'layerId' => '3',
        'decision' => {
          'variationId' => '122229',
          'experimentId' => '122227',
          'isLayerHoldback' => false,
        }
      }

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
    end

    it 'should properly track an event by calling dispatch_event with right params' do
      params = {
        'projectId' => '111001',
        'accountId' => '12001',
        'visitorId' => 'test_user',
        'userFeatures' => [],
        'clientEngine' => 'ruby-sdk',
        'clientVersion' => version,
        'timestamp' => (time_now.to_f * 1000).to_i,
        'isGlobalHoldback' => false,
        'eventEntityId' => '111095',
        'eventFeatures' => [],
        'eventName' => 'test_event',
        'eventMetrics' => [],
        'layerStates' => [
          {
            'layerId' => '1',
            'decision' => {
              'variationId' => '111128',
              'experimentId' => '111127',
              'isLayerHoldback' => false,
            },
            'actionTriggered' => true,
          }
        ]
      }

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should log a message if an exception has occurred during dispatching of the event' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(any_args).and_raise(RuntimeError)
      project_instance.track('test_event', 'test_user')
      expect(spy_logger).to have_received(:log).once.with(Logger::ERROR, "Unable to dispatch conversion event. Error: RuntimeError")
    end

    it 'should properly track an event by calling dispatch_event with right params with revenue provided' do
      params = {
        'projectId' => '111001',
        'accountId' => '12001',
        'visitorId' => 'test_user',
        'userFeatures' => [],
        'clientEngine' => 'ruby-sdk',
        'clientVersion' => version,
        'timestamp' => (time_now.to_f * 1000).to_i,
        'isGlobalHoldback' => false,
        'eventEntityId' => '111095',
        'eventFeatures' => [
          {
            'name' => 'revenue',
            'type' => 'custom',
            'value' => 42,
            'shouldIndex' => false
          }
        ],
        'eventName' => 'test_event',
        'eventMetrics' => [
          {
            'name' => 'revenue',
            'value' => 42,
          }
        ],
        'layerStates' => [
          {
            'layerId' => '1',
            'decision' => {
              'variationId' => '111128',
              'experimentId' => '111127',
              'isLayerHoldback' => false,
            },
            'actionTriggered' => true,
          }
        ]
      }

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user', nil, {'revenue' => 42})
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should properly track an event by calling dispatch_event with right params with deprecated revenue provided' do
      params = {
        'projectId' => '111001',
        'accountId' => '12001',
        'visitorId' => 'test_user',
        'userFeatures' => [],
        'clientEngine' => 'ruby-sdk',
        'clientVersion' => version,
        'timestamp' => (time_now.to_f * 1000).to_i,
        'isGlobalHoldback' => false,
        'eventEntityId' => '111095',
        'eventFeatures' => [
          {
            'name' => 'revenue',
            'type' => 'custom',
            'value' => 42,
            'shouldIndex' => false
          }
        ],
        'eventName' => 'test_event',
        'eventMetrics' => [
          {
            'name' => 'revenue',
            'value' => 42,
          }
        ],
        'layerStates' => [
          {
            'layerId' => '1',
            'decision' => {
              'variationId' => '111128',
              'experimentId' => '111127',
              'isLayerHoldback' => false,
            },
            'actionTriggered' => true,
          }
        ]
      }

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user', nil, 42)
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
      expect(spy_logger).to have_received(:log).once.with(Logger::WARN, 'Event value is deprecated in track call. Use event tags to pass in revenue value instead.')
    end

    it 'should properly track an event by calling dispatch_event with right params with attributes provided' do
      params = {
        'projectId' => '111001',
        'accountId' => '12001',
        'visitorId' => 'test_user',
        'userFeatures' => [
          {
            'id' => '111094',
            'name' => 'browser_type',
            'type' => 'custom',
            'value' => 'firefox',
            'shouldIndex' => true,
          }
        ],
        'clientEngine' => 'ruby-sdk',
        'clientVersion' => version,
        'timestamp' => (time_now.to_f * 1000).to_i,
        'isGlobalHoldback' => false,
        'eventEntityId' => '111097',
        'eventFeatures' => [],
        'eventName' => 'test_event_with_audience',
        'eventMetrics' => [],
        'layerStates' => [
          {
            'layerId' => '3',
            'decision' => {
              'variationId' => '122228',
              'experimentId' => '122227',
              'isLayerHoldback' => false,
            },
            'actionTriggered' => true,
          }
        ]
      }

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event_with_audience', 'test_user', 'browser_type' => 'firefox')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:post, conversion_log_url, params, post_headers)).once
    end

    it 'should not call dispatch_event when tracking an event for which audience conditions do not match' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event)
      project_instance.track('test_event_with_audience', 'test_user', 'browser_type' => 'cyberdog')
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
    end

    it 'should not call dispatch_event when tracking an event for which the experiment is not running' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event)
      project_instance.track('test_event_not_running', 'test_user')
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
    end

    it 'should log when a conversion event is dispatched' do
      params = {
        'projectId' => '111001',
        'accountId' => '12001',
        'visitorId' => 'test_user',
        'userFeatures' => [],
        'clientEngine' => 'ruby-sdk',
        'clientVersion' => version,
        'timestamp' => (time_now.to_f * 1000).to_i,
        'isGlobalHoldback' => false,
        'eventEntityId' => '111095',
        'eventName' => 'test_event',
        'eventFeatures' => [
          {
            'name' => 'revenue',
            'type' => 'custom',
            'value' => 42,
            'shouldIndex' => false
          }
        ],
        'eventMetrics' => [
          'name' => 'revenue',
          'value' => 42,
        ],
        'layerStates' => [
          {
            'layerId' => '1',
            'decision' => {
              'variationId' => '111128',
              'experimentId' => '111127',
              'isLayerHoldback' => false,
            },
            'actionTriggered' => true,
          }
        ]
      }

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user', nil, {'revenue' => 42})
      expect(spy_logger).to have_received(:log).with(Logger::INFO, include("Dispatching conversion event to" \
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

    it 'should return nil and not call dispatch_event if experiment_ids list is empty' do
      allow(project_instance.config).to receive(:get_experiment_ids_for_event).with(any_args).and_return([])
      allow(project_instance.event_dispatcher).to receive(:dispatch_event)

      expect(project_instance.track('invalid_event', 'test_user')).to eq(nil)
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
      expect(spy_logger).to have_received(:log).with(Logger::INFO, "Not tracking user 'test_user'.")
    end

    it 'should override the audience check if the user is whitelisted to a specific variation' do
      params = {
        'projectId' => '111001',
        'accountId' => '12001',
        'visitorId' => 'forced_audience_user',
        'userFeatures' => [
          {
            'id' => '111094',
            'name' => 'browser_type',
            'type' => 'custom',
            'value' => 'wrong_browser',
            'shouldIndex' => true,
          }
        ],
        'clientEngine' => 'ruby-sdk',
        'clientVersion' => version,
        'timestamp' => (time_now.to_f * 1000).to_i,
        'isGlobalHoldback' => false,
        'eventEntityId' => '111097',
        'eventFeatures' => [],
        'eventName' => 'test_event_with_audience',
        'eventMetrics' => [],
        'layerStates' => [
          {
            'layerId' => '3',
            'decision' => {
              'variationId' => '122229',
              'experimentId' => '122227',
              'isLayerHoldback' => false,
            },
            'actionTriggered' => true,
          }
        ]
      }
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
    it 'should have get_variation return expected variation when there are no audiences' do
      expect(project_instance.config).to receive(:get_audience_ids_for_experiment)
                                        .with('test_experiment')
                                        .and_return([])
      expect(project_instance.get_variation('test_experiment', 'test_user'))
             .to eq(config_body['experiments'][0]['variations'][0]['key'])
    end

    it 'should have get_variation return expected variation when audience conditions match' do
      user_attributes = {'browser_type' => 'firefox'}
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

    it 'should have get_variation return nil when experiment is not Running' do
      expect(project_instance.get_variation('test_experiment_not_started', 'test_user')).to eq(nil)
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
end
