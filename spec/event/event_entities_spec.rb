# frozen_string_literal: true

#
#    Copyright 2019, Optimizely and contributors
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
require 'optimizely/helpers/constants'
require 'optimizely/event/entity/event_batch'
require 'optimizely/event/entity/visitor_attribute'
require 'optimizely/event/entity/snapshot_event'
require 'optimizely/event/entity/decision'
require 'optimizely/event/entity/snapshot'
require 'optimizely/event/entity/visitor'
describe Optimizely::EventBatch do
  before(:example) do
    @time_now = Time.now
    allow(Time).to receive(:now).and_return(@time_now)
    allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')

    @expected_impression_payload = {
      account_id: '12001',
      project_id: '111001',
      visitors: [{
        attributes: [{
          entity_id: '7723280020',
          key: 'device_type',
          type: 'custom',
          value: 'iPhone'
        }, {
          entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          type: 'custom',
          value: true
        }],
        visitor_id: 'test_user',
        snapshots: [{
          decisions: [{
            campaign_id: '7719770039',
            experiment_id: '111127',
            variation_id: '111128'
          }],
          events: [{
            entity_id: '7719770039',
            timestamp: (@time_now.to_f * 1000).to_i,
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

    @expected_conversion_payload = {
      account_id: '12001',
      project_id: '111001',
      visitors: [{
        attributes: [{
          entity_id: '111094',
          key: 'test_value',
          type: 'custom',
          value: 'test_attribute'
        }],
        snapshots: [{
          events: [{
            entity_id: '111095',
            timestamp: (@time_now.to_f * 1000).to_i,
            uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
            key: 'test_event',
            value: 1.5,
            revenue: 42,
            event_tags: {
              'revenue' => 42,
              'non-revenue' => 42,
              'value': 1.5
            }
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

  it 'should return impression event equal to serialized payload' do
    builder = Optimizely::EventBatch::Builder.new
    builder.with_account_id('12001')
    builder.with_project_id('111001')
    builder.with_client_version(Optimizely::VERSION)
    builder.with_revision('42')
    builder.with_client_name(Optimizely::CLIENT_ENGINE)
    builder.with_anonymize_ip(false)
    builder.with_enrich_decisions(true)

    visitor_attribute_1 = Optimizely::VisitorAttribute.new('7723280020', 'device_type', 'custom', 'iPhone')
    visitor_attribute_2 = Optimizely::VisitorAttribute.new(
      Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      'custom',
      true
    )

    snapshot_event = Optimizely::SnapshotEvent.new(
      entity_id: '7719770039',
      timestamp: (@time_now.to_f * 1000).to_i,
      uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
      key: 'campaign_activated'
    )

    decision = Optimizely::Decision.new('7719770039', '111127', '111128')
    snapshot = Optimizely::Snapshot.new([snapshot_event.as_json], [decision.as_json])
    visitor = Optimizely::Visitor.new([snapshot.as_json], [visitor_attribute_1.as_json, visitor_attribute_2.as_json], 'test_user')
    builder.with_visitors([visitor.as_json])
    event_batch = builder.build

    expect(event_batch.as_json).to eq(@expected_impression_payload)
  end

  it 'should return conversion event equal to serialized payload' do
    builder = Optimizely::EventBatch::Builder.new
    builder.with_account_id('12001')
    builder.with_project_id('111001')
    builder.with_client_version(Optimizely::VERSION)
    builder.with_revision('42')
    builder.with_client_name(Optimizely::CLIENT_ENGINE)
    builder.with_anonymize_ip(false)
    builder.with_enrich_decisions(true)
    visitor_attribute = Optimizely::VisitorAttribute.new('111094', 'test_value', 'custom', 'test_attribute')

    snapshot_event = Optimizely::SnapshotEvent.new(
      entity_id: '111095',
      timestamp: (@time_now.to_f * 1000).to_i,
      uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
      key: 'test_event',
      value: 1.5,
      revenue: 42,
      event_tags: {
        'revenue' => 42,
        'non-revenue' => 42,
        'value': 1.5
      }
    )

    snapshot = Optimizely::Snapshot.new([snapshot_event.as_json])
    visitor = Optimizely::Visitor.new([snapshot.as_json], [visitor_attribute.as_json], 'test_user')
    builder.with_visitors([visitor.as_json])
    event_batch = builder.build

    expect(event_batch.as_json).to eq(@expected_conversion_payload)
  end
end
