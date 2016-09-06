require 'spec_helper'
require 'optimizely'
require 'optimizely/helpers/validator'
require 'optimizely/exceptions'
require 'optimizely/version'

describe Optimizely do
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

    it 'should throw an error when given a datafile that does not conform to the schema' do
      expect { Optimizely::Project.new('{"foo": "bar"}') }.to raise_error(Optimizely::InvalidDatafileError)
    end

    it 'should throw an error when given an invalid logger' do
      class InvalidLogger; end

      logger = InvalidLogger.new
      expect { Optimizely::Project.new(config_body_JSON, nil, logger) }
             .to raise_error(Optimizely::InvalidLoggerError)
    end

    it 'should throw an error when given an invalid event_dispatcher' do
      class InvalidEventDispatcher; end

      event_dispatcher = InvalidEventDispatcher.new
      expect { Optimizely::Project.new(config_body_JSON, event_dispatcher) }
             .to raise_error(Optimizely::InvalidEventDispatcherError)
    end

    it 'should throw an error when given an invalid error_handler' do
      class InvalidErrorHandler; end

      error_handler = InvalidErrorHandler.new
      expect { Optimizely::Project.new(config_body_JSON, nil, nil, error_handler) }
             .to raise_error(Optimizely::InvalidErrorHandlerError)
    end

    it 'should not validate the JSON schema of the datafile when skip_json_validation is true' do
      expect(Optimizely::Helpers::Validator).not_to receive(:datafile_valid?)

      Optimizely::Project.new(config_body_JSON, nil, nil, nil, true)
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
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:get, log_url, params)).once
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
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:get, log_url, params)).once
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
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:get, log_url, params)).once
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
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:get, log_url, params)).once
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
      expect(project_instance.event_dispatcher).to have_received(:dispatch_event).with(Optimizely::Event.new(:get, log_url, params)).once
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

      expect { project_instance.track('invalid_event', 'test_user') }.to raise_error(Optimizely::InvalidGoalError)
      expect(project_instance.event_dispatcher).to_not have_received(:dispatch_event)
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
end
