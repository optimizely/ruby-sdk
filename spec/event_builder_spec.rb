require 'spec_helper'
require 'webmock'
require 'optimizely/error_handler'
require 'optimizely/event_builder'
require 'optimizely/logger'

describe Optimizely::Event do
  before(:context) do
    @params = {
      'a' => '111001',
      'n' => 'test_event',
      'g' => '111028',
      'u' => 'test_user',
    }
    @event = Optimizely::Event.new(@params)
  end

  it 'should return URL when url is called' do
    expect(@event.url).to eq('https://111001.log.optimizely.com/event')
  end
end

describe Optimizely::EventBuilder do
  before(:context) do
    @version = Optimizely::VERSION
    @config_body = OptimizelySpec::CONFIG_BODY
    @config_body_JSON = OptimizelySpec::CONFIG_BODY_JSON
    @error_handler = Optimizely::NoOpErrorHandler.new
    @logger = Optimizely::SimpleLogger.new
  end

  before(:example) do
    config = Optimizely::ProjectConfig.new(@config_body_JSON, @logger, @error_handler)
    bucketer = Optimizely::Bucketer.new(config)
    @event_builder = Optimizely::EventBuilder.new(config, bucketer)
  end

  it 'should create Event object with right params when create_impression_event is called' do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)

    expected_params = {
      'd' => @config_body['accountId'],
      'a' => @config_body['projectId'],
      'n' => 'visitor-event',
      'g' => @config_body['events'][0]['id'],
      'u' => 'test_user',
      'x111127' => '111128',
      'src' => sprintf('ruby-sdk-%{version}', version: @version),
      'time' => time_now.strftime('%s').to_i
    }

    expect(@event_builder).to receive(:create_impression_event)
                          .with('test_experiment', 'test_user')
                          .and_return(Optimizely::Event.new(expected_params))
    impression_event = @event_builder.create_impression_event('test_experiment', 'test_user')
    expect(impression_event.params).to eq(expected_params)
  end

  it 'should create Event object with right params when create_impression_event is called with attributes' do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)

      expected_params = {
        'd' => @config_body['accountId'],
        'a' => @config_body['projectId'],
        'n' => 'visitor-event',
        'x122227' => '122228',
        'g' => '122227',
        'u' => 'test_user',
        's5175100584230912' => 'firefox',
        'src' => sprintf('ruby-sdk-%{version}', version: @version),
        'time' => time_now.strftime('%s').to_i
      }

      expect(@event_builder).to receive(:create_impression_event)
                            .with('test_experiment', 'test_user', {'browser_type' => 'firefox'})
                            .and_return(Optimizely::Event.new(expected_params))
      impression_event = @event_builder.create_impression_event('test_experiment',
                                                                'test_user',
                                                                {'browser_type' => 'firefox'})
      expect(impression_event.params).to eq(expected_params)
  end

  it 'should create Event object with right params when create_conversion_event is called' do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)

    expected_params = {
      'd' => @config_body['accountId'],
      'a' => @config_body['projectId'],
      'n' => 'test_event',
      'x122227' => '122228',
      'g' => '111095',
      'u' => 'test_user',
      'src' => sprintf('ruby-sdk-%{version}', version: @version),
      'time' => time_now.strftime('%s').to_i
    }

    expect(@event_builder).to receive(:create_conversion_event)
                          .with('test_event', 'test_user')
                          .and_return(Optimizely::Event.new(expected_params))
    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user')
    expect(conversion_event.params).to eq(expected_params)
  end

  it 'should create Event object with right params when create_conversion_event is called with attributes' do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)

    expected_params = {
      'd' => @config_body['accountId'],
      'a' => @config_body['projectId'],
      'n' => 'test_event',
      'x122227' => '122228',
      'g' => '111095',
      'u' => 'test_user',
      's5175100584230912' => 'firefox',
      'src' => sprintf('ruby-sdk-%{version}', version: @version),
      'time' => time_now.strftime('%s').to_i
    }

    expect(@event_builder).to receive(:create_conversion_event)
                          .with('test_event', 'test_user', {'browser_type' => 'firefox'})
                          .and_return(Optimizely::Event.new(expected_params))
    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', {'browser_type' => 'firefox'})
    expect(conversion_event.params).to eq(expected_params)
  end

  it 'should create Event object with right params when create_conversion_event is called with event value' do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)

    expected_params = {
      'd' => @config_body['accountId'],
      'a' => @config_body['projectId'],
      'n' => 'test_event',
      'x122227' => '122228',
      'g' => '111095',
      'u' => 'test_user',
      'v' => 42,
      'src' => sprintf('ruby-sdk-%{version}', version: @version),
      'time' => time_now.strftime('%s').to_i
    }

    expect(@event_builder).to receive(:create_conversion_event)
                          .with('test_event', 'test_user', nil, 42)
                          .and_return(Optimizely::Event.new(expected_params))
    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, 42)
    expect(conversion_event.params).to eq(expected_params)
  end
end
