# frozen_string_literal: true

# Copyright 2022, Optimizely
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'spec_helper'
require 'optimizely/odp/odp_manager'
require 'optimizely/odp/odp_event_manager'
require 'optimizely/odp/odp_event'
require 'optimizely/odp/lru_cache'
require 'optimizely/odp/odp_config'
require 'optimizely/odp/zaius_rest_api_manager'
require 'optimizely/logger'
require 'optimizely/helpers/validator'
require 'optimizely/helpers/constants'

describe Optimizely::OdpManager do
  let(:spy_logger) { spy('logger') }
  let(:api_host) { 'https://test-host' }
  let(:user_key) { 'fs_user_id' }
  let(:user_value) { 'test-user-value' }
  let(:api_key) { 'test-api-key' }
  let(:segments_to_check) { %w[a b c] }
  let(:test_uuid) { SecureRandom.uuid }
  let(:event) { {type: 't1', action: 'a1', identifiers: {'id-key-1': 'id-value-1'}, data: {'key-1': 'value1', "key-2": 2, "key-3": 3.0, "key-4": nil, 'key-5': true, 'key-6': false}} }
  let(:odp_event) { Optimizely::OdpEvent.new(**event) }

  describe '#initialize' do
    it 'should return default OdpManager instance' do
      manager = Optimizely::OdpManager.new(disable: false)

      odp_config = manager.instance_variable_get('@odp_config')
      expect(odp_config).to be_a Optimizely::OdpConfig

      logger = manager.instance_variable_get('@logger')
      expect(logger).to be_a Optimizely::NoOpLogger

      event_manager = manager.instance_variable_get('@event_manager')
      expect(event_manager).to be_a Optimizely::OdpEventManager
      expect(event_manager.odp_config).to be odp_config
      expect(event_manager.logger).to be logger
      expect(event_manager.running?).to be true

      segment_manager = manager.instance_variable_get('@segment_manager')
      expect(segment_manager).to be_a Optimizely::OdpSegmentManager
      expect(segment_manager.odp_config).to be odp_config
      expect(segment_manager.logger).to be logger

      segments_cache = segment_manager.segments_cache
      expect(segments_cache).to be_a Optimizely::LRUCache
      expect(segments_cache.instance_variable_get('@capacity')).to eq 10_000
      expect(segments_cache.instance_variable_get('@timeout')).to eq 600

      manager.close!
      expect(event_manager.running?).to be false
    end

    it 'should allow custom segment_manager' do
      segments_cache = Optimizely::LRUCache.new(1, 1)
      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache)
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      manager = Optimizely::OdpManager.new(disable: false, segments_cache: nil, segment_manager: segment_manager, logger: spy_logger)

      expect(manager.instance_variable_get('@segment_manager')).to be segment_manager
      expect(manager.instance_variable_get('@segment_manager').instance_variable_get('@segments_cache')).to be segments_cache

      manager.close!
    end

    it 'should allow custom segments_cache' do
      segments_cache = Optimizely::LRUCache.new(1, 1)
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      manager = Optimizely::OdpManager.new(disable: false, segments_cache: segments_cache, logger: spy_logger)

      expect(manager.instance_variable_get('@segment_manager').instance_variable_get('@segments_cache')).to be segments_cache

      manager.close!
    end

    it 'should allow custom event_manager' do
      event_manager = Optimizely::OdpEventManager.new
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      manager = Optimizely::OdpManager.new(disable: false, event_manager: event_manager, logger: spy_logger)

      expect(manager.instance_variable_get('@event_manager')).to be event_manager

      manager.close!
    end

    it 'should not instantiate event/segment managers when disabled' do
      expect(spy_logger).to receive(:log).once.with(Logger::INFO, 'ODP is not enabled.')
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      manager = Optimizely::OdpManager.new(disable: true, logger: spy_logger)

      expect(manager.instance_variable_get('@event_manager')).to be_nil
      expect(manager.instance_variable_get('@segment_manager')).to be_nil
    end
  end

  describe '#fetch_qualified_segments' do
    it 'should retrieve segments' do
      segments_cache = Optimizely::LRUCache.new(500, 500)
      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache)
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      manager = Optimizely::OdpManager.new(disable: false, segment_manager: segment_manager, logger: spy_logger)
      manager.update_odp_config(api_key, api_host, segments_to_check)

      cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      segments_cache.save(cache_key, [segments_to_check[0]])

      segments = manager.fetch_qualified_segments(user_id: user_value, options: nil)

      expect(segments).to eq [segments_to_check[0]]
      manager.close!
    end

    it 'should log error if disabled' do
      expect(spy_logger).to receive(:log).once.with(Logger::ERROR, Optimizely::Helpers::Constants::ODP_LOGS[:ODP_NOT_ENABLED])
      manager = Optimizely::OdpManager.new(disable: true, logger: spy_logger)

      response = manager.fetch_qualified_segments(user_id: 'user1', options: nil)
      expect(response).to be_nil
    end

    it 'should log error if datafile not ready' do
      expect(spy_logger).to receive(:log).with(Logger::ERROR, 'Cannot fetch segments before the datafile has loaded.')
      manager = Optimizely::OdpManager.new(disable: false, logger: spy_logger)

      response = manager.fetch_qualified_segments(user_id: 'user1', options: nil)
      expect(response).to be_nil
      manager.close!
    end

    it 'should ignore cache' do
      segments_cache = Optimizely::LRUCache.new(500, 500)
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, spy_logger)

      expect(segment_manager.zaius_manager)
        .to receive(:fetch_segments)
        .once
        .with(api_key, api_host, user_key, user_value, segments_to_check)
        .and_return([segments_to_check[0]])

      manager = Optimizely::OdpManager.new(disable: false, segment_manager: segment_manager, logger: spy_logger)
      manager.update_odp_config(api_key, api_host, segments_to_check)

      cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      segments_cache.save(cache_key, [segments_to_check[1]])

      segments = manager.fetch_qualified_segments(user_id: user_value, options: [Optimizely::OptimizelySegmentOption::IGNORE_CACHE])

      expect(segments).to eq [segments_to_check[0]]
      manager.close!
    end

    it 'should reset cache' do
      segments_cache = Optimizely::LRUCache.new(500, 500)
      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache)
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)

      expect(segment_manager.zaius_manager)
        .to receive(:fetch_segments)
        .once
        .with(api_key, api_host, user_key, user_value, segments_to_check)
        .and_return([segments_to_check[0]])

      manager = Optimizely::OdpManager.new(disable: false, segment_manager: segment_manager, logger: spy_logger)
      manager.update_odp_config(api_key, api_host, segments_to_check)

      segments_cache.save('wow', 'great')
      expect(segments_cache.lookup('wow')).to eq 'great'

      segments = manager.fetch_qualified_segments(user_id: user_value, options: [Optimizely::OptimizelySegmentOption::RESET_CACHE])

      expect(segments).to eq [segments_to_check[0]]
      expect(segments_cache.lookup('wow')).to be_nil
      manager.close!
    end
  end

  describe '#send_event' do
    it 'should send event' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)

      expect(event_manager.zaius_manager)
        .to receive(:send_odp_events)
        .once
        .with(api_key, api_host, [odp_event])
        .and_return(false)

      manager = Optimizely::OdpManager.new(disable: false, event_manager: event_manager, logger: spy_logger)
      manager.update_odp_config(api_key, api_host, segments_to_check)

      manager.send_event(**event)

      manager.close!
    end

    it 'should log error if data is invalid' do
      expect(spy_logger).to receive(:log).with(Logger::ERROR, 'ODP data is not valid.')

      manager = Optimizely::OdpManager.new(disable: false, logger: spy_logger)
      manager.update_odp_config(api_key, api_host, segments_to_check)
      event[:data][:bad_value] = {}

      manager.send_event(**event)

      manager.close!
    end
  end

  describe '#identify_user' do
    it 'should send event' do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      event_manager = Optimizely::OdpEventManager.new
      event = Optimizely::OdpEvent.new(type: 'fullstack', action: 'identified', identifiers: {user_key => user_value}, data: {})
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)

      expect(event_manager.zaius_manager)
        .to receive(:send_odp_events)
        .once
        .with(api_key, api_host, [event])
        .and_return(false)

      manager = Optimizely::OdpManager.new(disable: false, event_manager: event_manager, logger: spy_logger)
      manager.update_odp_config(api_key, api_host, segments_to_check)

      manager.identify_user(user_id: user_value)

      manager.close!
    end

    it 'should log debug if disabled' do
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to receive(:log).with(Logger::DEBUG, 'ODP identify event is not dispatched (ODP disabled).')

      manager = Optimizely::OdpManager.new(disable: true, logger: spy_logger)
      manager.identify_user(user_id: user_value)

      manager.close!
    end

    it 'should log debug if not integrated' do
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to receive(:log).with(Logger::DEBUG, 'ODP identify event is not dispatched (ODP not integrated).')
      manager = Optimizely::OdpManager.new(disable: false, logger: spy_logger)
      manager.update_odp_config(nil, nil, [])
      manager.identify_user(user_id: user_value)

      manager.close!
    end

    it 'should log debug if datafile not ready' do
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      expect(spy_logger).to receive(:log).with(Logger::DEBUG, 'ODP identify event is not dispatched (datafile not ready).')

      manager = Optimizely::OdpManager.new(disable: false, logger: spy_logger)
      manager.identify_user(user_id: user_value)

      manager.close!
    end
  end

  describe '#update_odp_config' do
    it 'update config' do
      expect(spy_logger).not_to receive(:log).with(Logger::ERROR, anything)
      manager = Optimizely::OdpManager.new(disable: false, logger: spy_logger)
      segment_manager = manager.instance_variable_get('@segment_manager')
      segments_cache = segment_manager.instance_variable_get('@segments_cache')
      segments_cache.save('wow', 'great')
      expect(segments_cache.lookup('wow')).to eq 'great'

      manager.update_odp_config(api_key, api_host, segments_to_check)

      manager_config = manager.instance_variable_get('@odp_config')
      expect(manager_config.api_host).to eq api_host
      expect(manager_config.api_key).to eq api_key
      expect(manager_config.segments_to_check).to eq segments_to_check

      segment_manager_config = segment_manager.odp_config
      expect(segment_manager_config.api_host).to eq api_host
      expect(segment_manager_config.api_key).to eq api_key
      expect(segment_manager_config.segments_to_check).to eq segments_to_check
      # confirm cache was reset
      expect(segments_cache.lookup('wow')).to be_nil

      event_manager = manager.instance_variable_get('@event_manager')
      sleep(0.1) until event_manager.instance_variable_get('@event_queue').empty?
      event_manager_config = event_manager.odp_config
      expect(event_manager_config.api_host).to eq api_host
      expect(event_manager_config.api_key).to eq api_key
      expect(event_manager_config.segments_to_check).to eq segments_to_check
      # confirm event_manager cached values were updated
      expect(event_manager.instance_variable_get('@api_host')).to eq api_host
      expect(event_manager.instance_variable_get('@api_key')).to eq api_key

      manager.close!
    end
  end
end
