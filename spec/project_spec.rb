require 'spec_helper'
require 'optimizely'
require 'optimizely/audience'
require 'optimizely/helpers/validator'
require 'optimizely/exceptions'
require 'optimizely/version'

describe 'OptimizelyV1' do
  let(:config_body) { OptimizelySpec::V1_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::V1_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:version) { Optimizely::VERSION }
  let(:log_url) { 'https://111001.log.optimizely.com/event' }
  let(:project_instance) { Optimizely::Project.new(config_body_JSON, nil, spy_logger, error_handler) }
  let(:time_now) { Time.now }

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
  end

  describe '#activate' do
    before(:example) do
      allow(Time).to receive(:now).and_return(time_now)
    end

    it 'should properly activate a user, invoke Event object with right params, and return variation' do
      params = {
        'd' => config_body['accountId'],
        'a' => config_body['projectId'],
        'n' => 'visitor-event',
        'x111127' => '111128',
        'g' => '111127',
        'u' => 'test_user',
        'src' => sprintf('ruby-sdk-%{version}', version: version),
        'time' => time_now.strftime('%s').to_i
      }

      allow(project_instance.bucketer).to receive(:bucket).and_return('111128')
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.config).to receive(:get_audience_ids_for_experiment)
                                    .with('test_experiment')
                                    .and_return([])

      stub_request(:get, log_url).with(:query => params)

      expect(project_instance.activate('test_experiment', 'test_user')).to eq('control')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:get, log_url, params, {})).once
      expect(project_instance.bucketer).to have_received(:bucket).once
    end

    it 'should properly activate a user, (with attributes provided) when there is an audience match' do
      params = {
        'd' => config_body['accountId'],
        'a' => config_body['projectId'],
        'n' => 'visitor-event',
        'x122227' => '122228',
        'g' => '122227',
        'u' => 'test_user',
        's5175100584230912' => 'firefox',
        'src' => sprintf('ruby-sdk-%{version}', version: version),
        'time' => time_now.strftime('%s').to_i
      }
      allow(project_instance.bucketer).to receive(:bucket).and_return('122228')
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))

      expect(project_instance.activate('test_experiment_with_audience', 'test_user', 'browser_type' => 'firefox'))
        .to eq('control_with_audience')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:get, log_url, params, {})).once
      expect(project_instance.bucketer).to have_received(:bucket).once
    end

    it 'should return nil when experiment status is not "Running"' do
      expect(project_instance.activate('test_experiment_not_started', 'test_user')).to eq(nil)
    end

    it 'should return nil when audience conditions do not match' do
      user_attributes = {'browser_type' => 'chrome'}
      expect(project_instance.activate('test_experiment_with_audience', 'test_user', user_attributes)).to eq(nil)
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
        'd' => config_body['accountId'],
        'a' => config_body['projectId'],
        'n' => 'visitor-event',
        'x111127' => '111128',
        'g' => '111127',
        'u' => 'test_user',
        'src' => sprintf('ruby-sdk-%{version}', version: version),
        'time' => time_now.strftime('%s').to_i
      }

      allow(project_instance.bucketer).to receive(:bucket).and_return('111128')
      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      allow(project_instance.config).to receive(:get_audience_ids_for_experiment)
                                        .with('test_experiment')
                                        .and_return([])
      project_instance.activate('test_experiment', 'test_user')
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, include("Dispatching impression event to" \
                                                                                " URL #{log_url} with params"))
    end

    it 'should raise an exception when called with invalid attributes' do
      expect { project_instance.activate('test_experiment', 'test_user', 'invalid') }
             .to raise_error(Optimizely::InvalidAttributeFormatError)
    end

    it 'should log an error when called with an invalid Project object' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }

      invalid_project = Optimizely::Project.new('invalid')
      invalid_project.activate('test_exp', 'test_user')
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting activate')
    end
  end

  describe '#track' do
    before(:example) do
      allow(Time).to receive(:now).and_return(time_now)
    end

    it 'should properly track an event by calling dispatch_event with right params' do
      params = {
        'd' => config_body['accountId'],
        'a' => config_body['projectId'],
        'n' => config_body['events'][0]['key'],
        'g' => config_body['events'][0]['id'],
        'u' => 'test_user',
        'x111127' => '111128',
        'src' => sprintf('ruby-sdk-%{version}', version: version),
        'time' => time_now.strftime('%s').to_i
      }

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:get, log_url, params, {})).once
    end

    it 'should properly track an event by calling dispatch_event with right params with revenue provided' do
      params = {
        'd' => config_body['accountId'],
        'a' => config_body['projectId'],
        'n' => config_body['events'][0]['key'],
        'g' => '111095,111096',
        'u' => 'test_user',
        'x111127' => '111128',
        'v' => 42,
        'src' => sprintf('ruby-sdk-%{version}', version: version),
        'time' => time_now.strftime('%s').to_i
      }

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user', nil, 42)
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:get, log_url, params, {})).once
    end

    it 'should properly track an event by calling dispatch_event with right params with attributes provided' do
      params = {
        'd' => config_body['accountId'],
        'a' => config_body['projectId'],
        'n' => config_body['events'][2]['key'],
        'g' => config_body['events'][2]['id'],
        'u' => 'test_user',
        'x122227' => '122228',
        's5175100584230912' => 'firefox',
        'src' => sprintf('ruby-sdk-%{version}', version: version),
        'time' => time_now.strftime('%s').to_i
      }

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event_with_audience', 'test_user', 'browser_type' => 'firefox')
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:get, log_url, params, {})).once
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
        'd' => config_body['accountId'],
        'a' => config_body['projectId'],
        'n' => config_body['events'][0]['key'],
        'g' => '111095,111096',
        'u' => 'test_user',
        'x111127' => '111128',
        'v' => 42,
        'src' => sprintf('ruby-sdk-%{version}', version: version),
        'time' => time_now.strftime('%s').to_i
      }

      allow(project_instance.event_dispatcher).to receive(:dispatch_event).with(instance_of(Optimizely::Event))
      project_instance.track('test_event', 'test_user', nil, 42)
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, include("Dispatching conversion event to" \
                                                                                " URL #{log_url} with params"))
    end

    it 'should raise an exception when called with attributes in an invalid format' do
      expect { project_instance.track('test_event', 'test_user', 'invalid') }
             .to raise_error(Optimizely::InvalidAttributeFormatError)
    end

    it 'should return nil and not call dispatch_event for an invalid event' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event)

      expect { project_instance.track('invalid_event', 'test_user') }.to raise_error(Optimizely::InvalidEventError)
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
    end

    it 'should log an error when called with an invalid Project object' do
      logger = double('logger')
      allow(logger).to receive(:log)
      allow(Optimizely::SimpleLogger).to receive(:new) { logger }

      invalid_project = Optimizely::Project.new('invalid')
      invalid_project.track('test_event', 'test_user')
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting track')
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
  end

  it 'should log an error when called with an invalid Project object' do
    logger = double('logger')
    allow(logger).to receive(:log)
    allow(Optimizely::SimpleLogger).to receive(:new) { logger }

    invalid_project = Optimizely::Project.new('invalid')
    invalid_project.get_variation('test_exp', 'test_user')
    expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting get_variation')
  end
end

describe 'OptimizelyV2' do
  let(:config_body) { OptimizelySpec::V2_CONFIG_BODY }
  let(:config_body_JSON) { OptimizelySpec::V2_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:version) { Optimizely::VERSION }
  let(:impression_log_url) { 'https://p13nlog.dz.optimizely.com/log/decision' }
  let(:conversion_log_url) { 'https://p13nlog.dz.optimizely.com/log/event' }
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

      invalid_project = Optimizely::Project.new('invalid')
      invalid_project.activate('test_exp', 'test_user')
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting activate')
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
        'eventFeatures' => [],
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
        'eventFeatures' => [],
        'eventName' => 'test_event',
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
      project_instance.track('test_event', 'test_user', nil, 42)
      expect(spy_logger).to have_received(:log).once.with(Logger::INFO, include("Dispatching conversion event to" \
                                                                                " URL #{conversion_log_url} with params #{params}"))
    end

    it 'should raise an exception when called with attributes in an invalid format' do
      expect { project_instance.track('test_event', 'test_user', 'invalid') }
             .to raise_error(Optimizely::InvalidAttributeFormatError)
    end

    it 'should return nil and not call dispatch_event for an invalid event' do
      allow(project_instance.event_dispatcher).to receive(:dispatch_event)

      expect { project_instance.track('invalid_event', 'test_user') }.to raise_error(Optimizely::InvalidEventError)
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
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

      invalid_project = Optimizely::Project.new('invalid')
      invalid_project.track('test_event', 'test_user')
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting track')
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

      invalid_project = Optimizely::Project.new('invalid')
      invalid_project.get_variation('test_exp', 'test_user')
      expect(logger).to have_received(:log).once.with(Logger::ERROR, 'Provided datafile is in an invalid format. Aborting get_variation')
    end
  end
end
