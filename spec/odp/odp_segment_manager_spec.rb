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
require 'optimizely/odp/odp_segment_manager'
require 'optimizely/odp/lru_cache'
require 'optimizely/odp/odp_config'
require 'optimizely/odp/odp_segment_api_manager'
require 'optimizely/logger'

describe Optimizely::OdpSegmentManager do
  let(:spy_logger) { spy('logger') }
  let(:api_host) { 'https://test-host' }
  let(:user_key) { 'fs_user_id' }
  let(:user_value) { 'test-user-value' }
  let(:api_key) { 'test-api-key' }
  let(:segments_to_check) { %w[a b c] }
  let(:segments_cache) { Optimizely::LRUCache.new(1000, 1000) }
  let(:good_response_data) do
    {
      data: {
        customer: {
          audiences: {
            edges: [
              {
                node: {
                  name: 'a',
                  state: 'qualified',
                  description: 'qualifed sample 1'
                }
              },
              {
                node: {
                  name: 'b',
                  state: 'qualified',
                  description: 'qualifed sample 2'
                }
              },
              {
                node: {
                  name: 'c',
                  state: 'not_qualified',
                  description: 'not-qualified sample'
                }
              }
            ]
          }
        }
      }
    }.to_json
  end

  describe '#initialize' do
    it 'should return OdpSegmentManager instance' do
      api_manager = Optimizely::OdpSegmentApiManager.new
      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, api_manager, spy_logger)

      expect(segment_manager.segments_cache).to be_a Optimizely::LRUCache
      expect(segment_manager.segments_cache).to be segments_cache
      expect(segment_manager.odp_config).to be nil
      expect(segment_manager.api_manager).to be api_manager
      expect(segment_manager.logger).to be spy_logger

      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache)
      expect(segment_manager.logger).to be_a Optimizely::NoOpLogger
      expect(segment_manager.api_manager).to be_a Optimizely::OdpSegmentApiManager
    end
  end

  describe '#fetch_qualified_segments' do
    it 'should return segments successfully' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .with({headers: {'x-api-key': api_key}, body: {
                query: 'query($userId: String, $audiences: [String]) {' \
                       "customer(#{user_key}: $userId) " \
                       '{audiences(subset: $audiences) {edges {node {name state}}}}}',
                variables: {userId: user_value, audiences: %w[a b c]}
              }})
        .to_return(status: 200, body: good_response_data)

      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, spy_logger)
      segment_manager.odp_config = Optimizely::OdpConfig.new(api_key, api_host, segments_to_check)

      segments = segment_manager.fetch_qualified_segments(user_key, user_value, [], nil)

      expect(segments).to match_array(%w[a b])
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should return empty array with no segments to check' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: good_response_data)

      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, spy_logger)
      segment_manager.odp_config = Optimizely::OdpConfig.new(api_key, api_host, [])

      segments = segment_manager.fetch_qualified_segments(user_key, user_value, [], nil)

      expect(segments).to match_array([])
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should return success with cache miss' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: good_response_data)

      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, spy_logger)
      segment_manager.odp_config = Optimizely::OdpConfig.new(api_key, api_host, %w[a b c])

      cache_key = segment_manager.send(:make_cache_key, user_key, '123')
      segment_manager.segments_cache.save(cache_key, %w[d])

      segments = segment_manager.fetch_qualified_segments(user_key, user_value, [], nil)

      expect(segments).to match_array(%w[a b])
      actual_cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      expect(segment_manager.segments_cache.lookup(actual_cache_key)).to match_array(%w[a b])
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should return success with cache hit' do
      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, spy_logger)
      segment_manager.odp_config = Optimizely::OdpConfig.new(api_key, api_host, %w[a b c])

      cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      segment_manager.segments_cache.save(cache_key, %w[c])

      segments = segment_manager.fetch_qualified_segments(user_key, user_value, [], nil)

      expect(segments).to match_array(%w[c])
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should return nil and log error with missing api_host/api_key' do
      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, spy_logger)
      segment_manager.odp_config = Optimizely::OdpConfig.new

      segments = segment_manager.fetch_qualified_segments(user_key, user_value, [], nil)

      expect(segments).to be_nil
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Audience segments fetch failed (ODP is not enabled).')
    end

    it 'should return nil with network error' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 500, body: '{}')

      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, spy_logger)
      segment_manager.odp_config = Optimizely::OdpConfig.new(api_key, api_host, segments_to_check)

      segments = segment_manager.fetch_qualified_segments(user_key, user_value, [], nil)

      expect(segments).to be_nil
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Audience segments fetch failed (500).')
    end

    it 'should return non cached value with ignore cache' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: good_response_data)

      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, spy_logger)
      segment_manager.odp_config = Optimizely::OdpConfig.new(api_key, api_host, %w[a b c])

      cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      segment_manager.segments_cache.save(cache_key, %w[d])

      segments = segment_manager.fetch_qualified_segments(user_key, user_value, [Optimizely::OptimizelySegmentOption::IGNORE_CACHE], nil)

      expect(segments).to match_array(%w[a b])
      expect(segment_manager.segments_cache.lookup(cache_key)).to match_array(%w[d])
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should reset cache and return non cached value with reset cache' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: good_response_data)

      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, spy_logger)
      segment_manager.odp_config = Optimizely::OdpConfig.new(api_key, api_host, %w[a b c])

      cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      segment_manager.segments_cache.save(cache_key, %w[d])
      segment_manager.segments_cache.save('123', %w[c d])

      segments = segment_manager.fetch_qualified_segments(user_key, user_value, [Optimizely::OptimizelySegmentOption::RESET_CACHE], nil)

      expect(segments).to match_array(%w[a b])
      expect(segment_manager.segments_cache.lookup(cache_key)).to match_array(%w[a b])
      expect(segment_manager.segments_cache.instance_variable_get('@map').length).to be 1
      expect(spy_logger).not_to have_received(:log).with(Logger::ERROR, anything)
    end

    it 'should make correct cache key' do
      segment_manager = Optimizely::OdpSegmentManager.new(nil, nil)
      cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      expect(cache_key).to be == "#{user_key}-$-#{user_value}"
    end

    it 'should log error if odp_config not set' do
      segment_manager = Optimizely::OdpSegmentManager.new(segments_cache, nil, spy_logger)

      response = segment_manager.fetch_qualified_segments(user_key, user_value, [], nil)
      expect(response).to be_nil
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'Audience segments fetch failed (ODP is not enabled).')
    end
  end
end
