# frozen_string_literal: true

#
#    Copyright 2019-2020, Optimizely and contributors
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
require 'optimizely/event/event_factory'
require 'optimizely/event/user_event_factory'
require 'optimizely/error_handler'
require 'optimizely/event_builder'
require 'optimizely/logger'
describe Optimizely::EventFactory do
  let(:config_body_JSON) { OptimizelySpec::VALID_CONFIG_BODY_JSON }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:project_config) { Optimizely::DatafileProjectConfig.new(config_body_JSON, spy_logger, error_handler) }
  let(:event) { project_config.get_event_from_key('test_event') }

  before(:example) do
    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)
    allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')

    @expected_endpoints = {
      US: 'https://logx.optimizely.com/v1/events',
      EU: 'https://eu.logx.optimizely.com/v1/events'
    }
    @expected_impression_params = {
      account_id: '12001',
      project_id: '111001',
      visitors: [{
        attributes: [{
          entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          type: 'custom',
          value: true
        }],
        visitor_id: 'test_user',
        snapshots: [{
          decisions: [{
            campaign_id: '1',
            experiment_id: '111127',
            variation_id: '111128',
            metadata: {
              flag_key: '',
              rule_key: 'test_experiment',
              rule_type: 'experiment',
              variation_key: '111128'
            }
          }],
          events: [{
            entity_id: '1',
            timestamp: Optimizely::Helpers::DateTimeUtils.create_timestamp,
            uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
            key: 'campaign_activated'
          }]
        }]
      }],
      anonymize_ip: false,
      revision: '42',
      client_name: Optimizely::CLIENT_ENGINE,
      enrich_decisions: true,
      client_version: Optimizely::VERSION
    }
    @expected_conversion_params = {
      account_id: '12001',
      project_id: '111001',
      visitors: [{
        attributes: [{
          entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          type: 'custom',
          value: true
        }],
        visitor_id: 'test_user',
        snapshots: [{
          events: [{
            entity_id: '111095',
            timestamp: Optimizely::Helpers::DateTimeUtils.create_timestamp,
            uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
            key: 'test_event'
          }]
        }]
      }],
      anonymize_ip: false,
      revision: '42',
      client_name: Optimizely::CLIENT_ENGINE,
      enrich_decisions: true,
      client_version: Optimizely::VERSION
    }
  end

  it 'should create valid Event when create_impression_event is called without attributes' do
    experiment = project_config.get_experiment_from_key('test_experiment')
    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', metadata, 'test_user', nil)
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create valid Event when create_impression_event is called without attributes and with EU' do
    experiment = project_config.get_experiment_from_key('test_experiment')
    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    allow_any_instance_of(Optimizely::ImpressionEvent).to receive(:event_context).and_return(
      {
        account_id: '12001',
        project_id: '111001',
        client_version: Optimizely::VERSION,
        revision: '42',
        client_name: Optimizely::CLIENT_ENGINE,
        anonymize_ip: false,
        region: 'EU'
      }
    )
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', metadata, 'test_user', nil)
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:EU])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_impression_event is called with attributes as a string value' do
    @expected_impression_params[:visitors][0][:attributes].unshift(
      entity_id: '111094',
      key: 'browser_type',
      type: 'custom',
      value: 'firefox'
    )

    experiment = project_config.get_experiment_from_key('test_experiment')
    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', metadata, 'test_user',
                                                                            'browser_type' => 'firefox')
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_impression_event is called with attributes of different valid types' do
    @expected_impression_params[:visitors][0][:attributes] = [
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
      }, {
        entity_id: '111097',
        key: 'double_key',
        type: 'custom',
        value: 5.5
      },
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      type: 'custom',
      value: true
    ]

    experiment = project_config.get_experiment_from_key('test_experiment')
    attributes = {
      'browser_type' => 'firefox',
      'boolean_key' => true,
      'integer_key' => 5,
      'double_key' => 5.5
    }

    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', metadata, 'test_user', attributes)
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event and exclude attributes of invalid types' do
    @expected_impression_params[:visitors][0][:attributes] = [
      {
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'firefox'
      },
      {
        entity_id: '111096',
        key: 'integer_key',
        type: 'custom',
        value: 5
      },
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      type: 'custom',
      value: true
    ]

    experiment = project_config.get_experiment_from_key('test_experiment')
    attributes = {
      'browser_type' => 'firefox',
      'boolean_key' => nil,
      'integer_key' => 5,
      'double_key' => {}
    }

    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', metadata, 'test_user', attributes)
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_impression_event is called with attributes as a false value' do
    @expected_impression_params[:visitors][0][:attributes].unshift(
      entity_id: '111094',
      key: 'browser_type',
      type: 'custom',
      value: false
    )

    experiment = project_config.get_experiment_from_key('test_experiment')
    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', metadata, 'test_user',
                                                                            'browser_type' => false)
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_impression_event is called with attributes as a zero value' do
    @expected_impression_params[:visitors][0][:attributes].unshift(
      entity_id: '111094',
      key: 'browser_type',
      type: 'custom',
      value: 0
    )

    experiment = project_config.get_experiment_from_key('test_experiment')
    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', metadata, 'test_user', 'browser_type' => 0)
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_impression_event is called with attributes is not in the datafile' do
    experiment = project_config.get_experiment_from_key('test_experiment')
    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', metadata, 'test_user',
                                                                            invalid_attribute: 'sorry_not_sorry')
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called' do
    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with attributes' do
    @expected_conversion_params[:visitors][0][:attributes].unshift(
      entity_id: '111094',
      key: 'browser_type',
      type: 'custom',
      value: 'firefox'
    )

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', {'browser_type' => 'firefox'}, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with revenue event tag' do
    event_tags = {'revenue' => 4200}

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 4200,
                                                                                tags: event_tags)

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with valid string revenue event tag' do
    event_tags = {'revenue' => '4200'}

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 4200,
                                                                                tags: event_tags)

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with invalid revenue event tag' do
    event_tags = {'revenue' => 'invalid revenue'}

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with non-revenue event tag' do
    event_tags = {'non-revenue' => 4200}

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with revenue and non-revenue event tags' do
    event_tags = {
      'revenue' => 4200,
      'non-revenue' => 4200
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 4200,
                                                                                tags: event_tags)

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with boolean event tag' do
    event_tags = {
      'boolean_tag' => false,
      'nil_tag' => nil
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with string event tag' do
    event_tags = {
      'string_tag' => 'iamstring'
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with integer event tag' do
    event_tags = {
      'integer_tag' => 42
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with float event tag' do
    event_tags = {
      'float_tag' => 42.01
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with value event tag' do
    event_tags = {
      'value' => '13.37'
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0].merge!(value: 13.37,
                                                                                tags: event_tags)

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with invalid value event tag' do
    event_tags = {
      'value' => 'invalid value'
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', nil, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with attributes and event tags for revenue, '\
     'value and other tag' do
    event_tags = {
      'revenue' => 4200,
      'value' => 13.37,
      'other' => 'some value'
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 4200,
                                                                                value: 13.37,
                                                                                tags: event_tags)

    @expected_conversion_params[:visitors][0][:attributes].unshift(
      entity_id: '111094',
      key: 'browser_type',
      type: 'custom',
      value: 'firefox'
    )

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', {'browser_type' => 'firefox'}, event_tags)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  # Create impression event with bucketing ID
  it 'should create valid Event when create_impression_event is called with Bucketing ID attribute' do
    @expected_impression_params[:visitors][0][:attributes].unshift(
      {
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'firefox'
      },
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'],
      type: 'custom',
      value: 'variation'
    )

    user_attributes = {
      'browser_type' => 'firefox',
      '$opt_bucketing_id' => 'variation'
    }
    experiment = project_config.get_experiment_from_key('test_experiment')
    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', metadata, 'test_user', user_attributes)
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create valid Event with user agent when bot_filtering is enabled' do
    # Test that create_impression_event creates Event object
    # with right params when user agent attribute is provided and
    # bot filtering is enabled

    @expected_impression_params[:visitors][0][:attributes] = [{
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      type: 'custom',
      value: true
    }]

    @expected_impression_params[:visitors][0][:attributes].unshift(
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      type: 'custom',
      value: 'test'
    )
    user_attributes = {
      '$opt_user_agent' => 'test'
    }
    experiment = project_config.get_experiment_from_key('test_experiment')
    expect(project_config.send(:bot_filtering)).to eq(true)
    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    impression_event = Optimizely::UserEventFactory.create_impression_event(project_config, experiment, '111128', metadata, 'test_user', user_attributes)
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create valid Event with user agent when bot_filtering is disabled' do
    # Test that create_impression_event creates Event object
    # with right params when user agent attribute is provided and
    # bot filtering is disabled

    @expected_impression_params[:visitors][0][:attributes] = [{
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      type: 'custom',
      value: false
    }]
    @expected_impression_params[:visitors][0][:attributes].unshift(
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      type: 'custom',
      value: 'test'
    )

    user_attributes = {
      '$opt_user_agent' => 'test'
    }
    experiment = project_config.get_experiment_from_key('test_experiment')
    allow(project_config).to receive(:bot_filtering).and_return(false)
    metadata = {
      flag_key: '',
      rule_key: 'test_experiment',
      rule_type: 'experiment',
      variation_key: '111128'
    }
    impression_event = Optimizely::UserEventFactory.create_impression_event(
      project_config, experiment, '111128', metadata, 'test_user', user_attributes
    )
    log_event = Optimizely::EventFactory.create_log_event(impression_event, spy_logger)
    expect(log_event.params).to eq(@expected_impression_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  # Create conversion event with bucketing ID
  it 'should create valid Event when create_conversion_event is called with Bucketing ID attribute' do
    @expected_conversion_params[:visitors][0][:attributes].unshift(
      {
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'firefox'
      },
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'],
      type: 'custom',
      value: 'variation'
    )

    user_attributes = {
      'browser_type' => 'firefox',
      '$opt_bucketing_id' => 'variation'
    }
    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', user_attributes, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create valid Event when create_conversion_event is called with Bucketing ID attribute and with EU' do
    @expected_conversion_params[:visitors][0][:attributes].unshift(
      {
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'firefox'
      },
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'],
      type: 'custom',
      value: 'variation'
    )

    user_attributes = {
      'browser_type' => 'firefox',
      '$opt_bucketing_id' => 'variation'
    }

    allow_any_instance_of(Optimizely::ConversionEvent).to receive(:event_context).and_return(
      {
        account_id: '12001',
        project_id: '111001',
        client_version: Optimizely::VERSION,
        revision: '42',
        client_name: Optimizely::CLIENT_ENGINE,
        anonymize_ip: false,
        region: 'EU'
      }
    )

    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', user_attributes, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:EU])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create valid Event with user agent when bot_filtering is enabled' do
    # Test that create_conversion_event creates Event object
    # with right params when user agent attribute is provided and
    # bot filtering is enabled

    @expected_conversion_params[:visitors][0][:attributes].unshift(
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      type: 'custom',
      value: 'test'
    )

    user_attributes = {
      '$opt_user_agent' => 'test'
    }
    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', user_attributes, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  it 'should create valid Event with user agent when bot_filtering is disabled' do
    # Test that create_conversion_event creates Event object
    # with right params when user agent attribute is provided and
    # bot filtering is disabled
    @expected_conversion_params[:visitors][0][:attributes] = [{
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      type: 'custom',
      value: false
    }]

    @expected_conversion_params[:visitors][0][:attributes].unshift(
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      type: 'custom',
      value: 'test'
    )

    user_attributes = {
      '$opt_user_agent' => 'test'
    }
    allow(project_config).to receive(:bot_filtering).and_return(false)
    conversion_event = Optimizely::UserEventFactory.create_conversion_event(project_config, event, 'test_user', user_attributes, nil)
    log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
    expect(log_event.params).to eq(@expected_conversion_params)
    expect(log_event.url).to eq(@expected_endpoints[:US])
    expect(log_event.http_verb).to eq(:post)
  end

  # ----------------------------------------------------------------------
  # FSSDK-12813: Decision-event ID normalization tests.
  #
  # These integration tests exercise the EventFactory wire payload to verify
  # that campaign_id, variation_id, and entity_id are normalized uniformly
  # across every decision type (experiment, feature test, rollout, holdout).
  # ----------------------------------------------------------------------
  describe 'FSSDK-12813 decision event ID normalization' do
    let(:event_context) do
      Optimizely::EventContext.new(
        region: 'US',
        account_id: '12001',
        project_id: '111001',
        anonymize_ip: false,
        revision: '42',
        client_name: Optimizely::CLIENT_ENGINE,
        client_version: Optimizely::VERSION
      ).as_json
    end
    let(:metadata) do
      {
        flag_key: 'flag_a',
        rule_key: 'rule_a',
        rule_type: 'experiment',
        variation_key: 'var_a',
        enabled: true
      }
    end

    def build_impression(experiment_layer_id:, experiment_id:, variation_id:)
      Optimizely::ImpressionEvent.new(
        event_context: event_context,
        user_id: 'test_user',
        experiment_layer_id: experiment_layer_id,
        experiment_id: experiment_id,
        variation_id: variation_id,
        metadata: metadata,
        visitor_attributes: [],
        bot_filtering: nil
      )
    end

    def first_decision(log_event)
      log_event.params[:visitors][0][:snapshots][0][:decisions][0]
    end

    def first_event(log_event)
      log_event.params[:visitors][0][:snapshots][0][:events][0]
    end

    it 'passes valid numeric campaign_id and variation_id through unchanged' do
      impression = build_impression(
        experiment_layer_id: '111111', experiment_id: '222222', variation_id: '333333'
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      decision = first_decision(log_event)
      event = first_event(log_event)

      expect(decision[:campaign_id]).to eq('111111')
      expect(decision[:experiment_id]).to eq('222222')
      expect(decision[:variation_id]).to eq('333333')
      expect(event[:entity_id]).to eq('111111')
      expect(event[:entity_id]).to eq(decision[:campaign_id])
    end

    it 'substitutes experiment_id when campaign_id (layerId) is nil' do
      # FR-001/FR-002: nil campaign_id must be replaced with experiment_id.
      impression = build_impression(
        experiment_layer_id: nil, experiment_id: '222222', variation_id: '333333'
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      decision = first_decision(log_event)
      event = first_event(log_event)

      expect(decision[:campaign_id]).to eq('222222')
      # FR-009: entity_id must equal decisions[].campaign_id byte-for-byte.
      expect(event[:entity_id]).to eq('222222')
    end

    it 'substitutes experiment_id when campaign_id is an empty string' do
      impression = build_impression(
        experiment_layer_id: '', experiment_id: '222222', variation_id: '333333'
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      expect(first_decision(log_event)[:campaign_id]).to eq('222222')
      expect(first_event(log_event)[:entity_id]).to eq('222222')
    end

    it 'passes whitespace campaign_id through unchanged (FSSDK-12813 relaxed contract: non-empty string)' do
      # Per relaxed spec, any non-empty string is valid for campaign_id —
      # only empty string / nil / missing trigger the experiment_id fallback.
      impression = build_impression(
        experiment_layer_id: '   ', experiment_id: '222222', variation_id: '333333'
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      expect(first_decision(log_event)[:campaign_id]).to eq('   ')
      expect(first_event(log_event)[:entity_id]).to eq('   ')
    end

    it 'passes non-numeric opaque campaign_id through unchanged (FSSDK-12813 relaxed contract)' do
      # Per relaxed spec, opaque IDs such as "default-12345" or "layer_abc"
      # are valid for campaign_id and entity_id; only empty/null trigger the
      # experiment_id fallback.
      impression = build_impression(
        experiment_layer_id: 'campaign_a', experiment_id: '222222', variation_id: '333333'
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      expect(first_decision(log_event)[:campaign_id]).to eq('campaign_a')
      expect(first_event(log_event)[:entity_id]).to eq('campaign_a')
    end

    it 'passes prefixed opaque campaign_id (default-12345) through unchanged (FSSDK-12813)' do
      impression = build_impression(
        experiment_layer_id: 'default-12345', experiment_id: '222222', variation_id: '333333'
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      expect(first_decision(log_event)[:campaign_id]).to eq('default-12345')
      expect(first_event(log_event)[:entity_id]).to eq('default-12345')
    end

    it 'falls back to empty string when both campaign_id and experiment_id are invalid' do
      # Mirrors the legacy empty-slot impression case that send_impression emits
      # when there is no decision (e.g. send_flag_decisions and no rule matched).
      impression = build_impression(
        experiment_layer_id: '', experiment_id: '', variation_id: nil
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      decision = first_decision(log_event)
      event = first_event(log_event)

      expect(decision[:campaign_id]).to eq('')
      expect(decision[:variation_id]).to be_nil
      expect(event[:entity_id]).to eq('')
    end

    it 'normalizes invalid variation_id to nil (empty string case)' do
      # FR-003/FR-004: empty variation_id becomes nil.
      impression = build_impression(
        experiment_layer_id: '111111', experiment_id: '222222', variation_id: ''
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      expect(first_decision(log_event)[:variation_id]).to be_nil
    end

    it 'normalizes invalid variation_id to nil (non-numeric placeholder case)' do
      impression = build_impression(
        experiment_layer_id: '111111', experiment_id: '222222', variation_id: 'variation_a'
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      expect(first_decision(log_event)[:variation_id]).to be_nil
    end

    it 'normalizes invalid variation_id to nil (whitespace case)' do
      impression = build_impression(
        experiment_layer_id: '111111', experiment_id: '222222', variation_id: '   '
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      expect(first_decision(log_event)[:variation_id]).to be_nil
    end

    it 'normalizes invalid variation_id to nil (non-string case)' do
      impression = build_impression(
        experiment_layer_id: '111111', experiment_id: '222222', variation_id: 333_333
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      expect(first_decision(log_event)[:variation_id]).to be_nil
    end

    it 'leaves valid nil variation_id as nil (already-normalized)' do
      impression = build_impression(
        experiment_layer_id: '111111', experiment_id: '222222', variation_id: nil
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      expect(first_decision(log_event)[:variation_id]).to be_nil
    end

    it 'applies the same normalization for holdout decision metadata (FR-005)' do
      # FR-005: normalization must be uniform across decision types. A holdout
      # decision carries rule_type 'holdout' in metadata but still flows through
      # the same impression factory path — so the same normalization applies.
      holdout_metadata = metadata.merge(rule_type: 'holdout')
      impression = Optimizely::ImpressionEvent.new(
        event_context: event_context,
        user_id: 'test_user',
        experiment_layer_id: '', # holdout with no layer id
        experiment_id: '999777', # falls back to holdout id
        variation_id: 'invalid_placeholder',
        metadata: holdout_metadata,
        visitor_attributes: [],
        bot_filtering: nil
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      decision = first_decision(log_event)
      event = first_event(log_event)

      expect(decision[:campaign_id]).to eq('999777')
      expect(decision[:variation_id]).to be_nil
      expect(event[:entity_id]).to eq('999777')
      expect(decision[:metadata][:rule_type]).to eq('holdout')
    end

    it 'does not log or warn on the normalization path (FR-007)' do
      impression = build_impression(
        experiment_layer_id: '', experiment_id: '222222', variation_id: 'bad'
      )
      Optimizely::EventFactory.create_log_event(impression, spy_logger)

      # spy_logger.log should not have been invoked for any normalization
      # bookkeeping (we still allow other log calls from upstream code paths,
      # but in this isolated test there are none).
      expect(spy_logger).not_to have_received(:log)
    end

    it 'still emits the event payload when IDs are invalid (FR-006: do not drop)' do
      impression = build_impression(
        experiment_layer_id: nil, experiment_id: nil, variation_id: 'bad'
      )
      log_event = Optimizely::EventFactory.create_log_event(impression, spy_logger)
      expect(log_event).not_to be_nil
      expect(log_event.params[:visitors][0][:snapshots][0][:decisions]).not_to be_empty
      expect(log_event.params[:visitors][0][:snapshots][0][:events]).not_to be_empty
    end

    it 'does not normalize conversion event entity_id (FR-010)' do
      # Conversion events derive entity_id from the event id source and must
      # remain unchanged. The conversion fixture's entity_id (111095) is
      # already numeric and must be preserved verbatim.
      experiment_event = project_config.get_event_from_key('test_event')
      allow(project_config).to receive(:bot_filtering).and_return(true)
      conversion_event = Optimizely::UserEventFactory.create_conversion_event(
        project_config, experiment_event, 'test_user', nil, nil
      )
      log_event = Optimizely::EventFactory.create_log_event(conversion_event, spy_logger)
      expect(first_event(log_event)[:entity_id]).to eq('111095')
    end
  end
end
