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
require 'webmock'
require 'optimizely/error_handler'
require 'optimizely/event_builder'
require 'optimizely/logger'

describe Optimizely::EventBuilderV2 do
  before(:context) do
    @config_body = OptimizelySpec::V2_CONFIG_BODY
    @config_body_JSON = OptimizelySpec::V2_CONFIG_BODY_JSON
    @error_handler = Optimizely::NoOpErrorHandler.new
    @logger = Optimizely::SimpleLogger.new
  end

  before(:example) do
    config = Optimizely::ProjectConfig.new(@config_body_JSON, @logger, @error_handler)
    bucketer = Optimizely::Bucketer.new(config)
    @event_builder = Optimizely::EventBuilderV2.new(config, bucketer)

    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)

    @expected_impression_url = 'https://p13nlog.dz.optimizely.com/log/decision'
    @expected_impression_params = {
      'visitorId' => 'test_user',
      'timestamp' => (time_now.to_f * 1000).to_i,
      'isGlobalHoldback' => false,
      'projectId' => '111001',
      'decision' => {
        'variationId' => '111128',
        'experimentId' => '111127',
        'isLayerHoldback' => false,
      },
      'layerId' => '1',
      'accountId' => '12001',
      'clientEngine' => 'ruby-sdk',
      'clientVersion' => Optimizely::VERSION,
      'userFeatures' => [],
    }

    @expected_conversion_url = 'https://p13nlog.dz.optimizely.com/log/event'
    @expected_conversion_params = {
      'visitorId' => 'test_user',
      'timestamp' => (time_now.to_f * 1000).to_i,
      'isGlobalHoldback' => false,
      'projectId' => '111001',
      'accountId' => '12001',
      'clientEngine' => 'ruby-sdk',
      'clientVersion' => Optimizely::VERSION,
      'userFeatures' => [],
      'eventMetrics' => [],
      'eventFeatures' => [],
      'eventName' => 'test_event',
      'eventEntityId' => '111095',
      'layerStates' => [{
        'layerId' => '1',
        'decision' => {
          'variationId' => '111128',
          'experimentId' => '111127',
          'isLayerHoldback' => false,
        },
        'actionTriggered' => true,
      }],
    }
  end

  it 'should create a valid V2 Event when create_impression_event is called' do
    impression_event = @event_builder.create_impression_event('test_experiment', '111128', 'test_user', nil)
    expect(impression_event.params).to eq(@expected_impression_params)
    expect(impression_event.url).to eq(@expected_impression_url)
    expect(impression_event.http_verb).to eq(:post)
  end

  it 'should create a valid V2 Event when create_impression_event is called with attributes' do
    @expected_impression_params['userFeatures'] = [{
      'id' => '111094',
      'name' => 'browser_type',
      'type' => 'custom',
      'value' => 'firefox',
      'shouldIndex' => true,
    }]

    impression_event = @event_builder.create_impression_event('test_experiment', '111128', 'test_user', {'browser_type' => 'firefox'})
    expect(impression_event.params).to eq(@expected_impression_params)
    expect(impression_event.url).to eq(@expected_impression_url)
    expect(impression_event.http_verb).to eq(:post)
  end

  it 'should create a valid V2 Event when create_conversion_event is called' do
    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, nil, ['test_experiment'])
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_conversion_url)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid V2 Event when create_conversion_event is called with attributes' do
    @expected_conversion_params['userFeatures'] = [{
      'id' => '111094',
      'name' => 'browser_type',
      'type' => 'custom',
      'value' => 'firefox',
      'shouldIndex' => true,
    }]

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', {'browser_type' => 'firefox'}, nil, ['test_experiment'])
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_conversion_url)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid V2 Event when create_conversion_event is called with revenue event tag' do
    @expected_conversion_params['eventMetrics'] = [{
      'name' => 'revenue',
      'value' => 4200,
    }]
    @expected_conversion_params['eventFeatures'] = [
      {
        'name' => 'revenue',
        'type' => 'custom',
        'value' => 4200,
        'shouldIndex' => false
      },
    ]

    event_tags = {'revenue' => 4200}

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags, ['test_experiment'])
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_conversion_url)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid V2 Event when create_conversion_event is called with revenue event tag' do
    @expected_conversion_params['eventMetrics'] = []
    @expected_conversion_params['eventFeatures'] = [
      {
        'name' => 'revenue',
        'type' => 'custom',
        'value' => "4200",
        'shouldIndex' => false
      },
    ]

    event_tags = {'revenue' => '4200'}

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags, ['test_experiment'])
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_conversion_url)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid V2 Event when create_conversion_event is called with boolean event tag' do
    @expected_conversion_params['eventFeatures'] = [
      {
        'name' => 'boolean_tag',
        'type' => 'custom',
        'value' => false,
        'shouldIndex' => false
      },
    ]

    event_tags = {
      'boolean_tag' => false,
      'nil_tag' => nil
    }

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags, ['test_experiment'])
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_conversion_url)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid V2 Event when create_conversion_event is called with string event tag' do
    @expected_conversion_params['eventFeatures'] = [
      {
        'name' => 'string_tag',
        'type' => 'custom',
        'value' => 'iamstring',
        'shouldIndex' => false
      },
    ]

    event_tags = {
      'string_tag' => 'iamstring',
    }

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags, ['test_experiment'])
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_conversion_url)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid V2 Event when create_conversion_event is called with integer event tag' do
    @expected_conversion_params['eventFeatures'] = [
      {
        'name' => 'integer_tag',
        'type' => 'custom',
        'value' => 42,
        'shouldIndex' => false
      },
    ]

    event_tags ={
      'integer_tag' => 42,
    }

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags, ['test_experiment'])
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_conversion_url)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid V2 Event when create_conversion_event is called with float event tag' do
    @expected_conversion_params['eventFeatures'] = [
      {
        'name' => 'float_tag',
        'type' => 'custom',
        'value' => 42.01,
        'shouldIndex' => false
      },
    ]

    event_tags = {
      'float_tag' => 42.01,
    }

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags, ['test_experiment'])
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_conversion_url)
    expect(conversion_event.http_verb).to eq(:post)
  end
end

describe Optimizely::EventBuilderV1 do
  before(:context) do
    @version = Optimizely::VERSION
    @config_body = OptimizelySpec::V1_CONFIG_BODY
    @config_body_JSON = OptimizelySpec::V1_CONFIG_BODY_JSON
    @error_handler = Optimizely::NoOpErrorHandler.new
    @logger = Optimizely::SimpleLogger.new
  end

  before(:example) do
    config = Optimizely::ProjectConfig.new(@config_body_JSON, @logger, @error_handler)
    bucketer = Optimizely::Bucketer.new(config)
    @event_builder = Optimizely::EventBuilderV1.new(config, bucketer)
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
                          .and_return(Optimizely::Event.new(:get, '', expected_params, {}))
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
                            .and_return(Optimizely::Event.new(:get, '', expected_params, {}))
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
                          .and_return(Optimizely::Event.new(:get, '', expected_params, {}))
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
                          .and_return(Optimizely::Event.new(:get, '', expected_params, {}))
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
                          .with('test_event', 'test_user', nil, {'revenue' => 42})
                          .and_return(Optimizely::Event.new(:get, '', expected_params, {}))
    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, {'revenue' => 42})
    expect(conversion_event.params).to eq(expected_params)
  end

  it 'should create Event object with right params when create_conversion_event is called with no tags' do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)

    expected_params = {
      'd' => @config_body['accountId'],
      'a' => @config_body['projectId'],
      'n' => 'test_event',
      'g' => '111095',
      'u' => 'test_user',
      'src' => sprintf('ruby-sdk-%{version}', version: @version),
      'time' => time_now.strftime('%s').to_i
    }

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, nil, [])
    expect(conversion_event.params).to eq(expected_params)
  end

  it 'should create Event object with right params when create_conversion_event is called with non-revenue tags' do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)

    expected_params = {
      'd' => @config_body['accountId'],
      'a' => @config_body['projectId'],
      'n' => 'test_event',
      'g' => '111095',
      'u' => 'test_user',
      'src' => sprintf('ruby-sdk-%{version}', version: @version),
      'time' => time_now.strftime('%s').to_i
    }

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, {'non-revenue' => 42}, [])
    expect(conversion_event.params).to eq(expected_params)
  end

  it 'should create Event object with right params when create_conversion_event is called with revenue tags' do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)

    expected_params = {
      'd' => @config_body['accountId'],
      'a' => @config_body['projectId'],
      'n' => 'test_event',
      'g' => '111095,111096',
      'u' => 'test_user',
      'v' => 42,
      'src' => sprintf('ruby-sdk-%{version}', version: @version),
      'time' => time_now.strftime('%s').to_i
    }

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, {'revenue' => 42}, [])
    expect(conversion_event.params).to eq(expected_params)
  end

  it 'should create Event object with right params when create_conversion_event is called with invalid revenue tag' do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)

    expected_params = {
      'd' => @config_body['accountId'],
      'a' => @config_body['projectId'],
      'n' => 'test_event',
      'g' => '111095',
      'u' => 'test_user',
      'src' => sprintf('ruby-sdk-%{version}', version: @version),
      'time' => time_now.strftime('%s').to_i
    }

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, {'revenue' => '42'}, [])
    expect(conversion_event.params).to eq(expected_params)
  end
end
