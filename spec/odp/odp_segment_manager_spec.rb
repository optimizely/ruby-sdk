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
require 'optimizely/odp/zaius_graphql_api_manager'
require 'optimizely/logger'

describe Optimizely::OdpSegmentManager do
  let(:spy_logger) { spy('logger') }
  let(:api_host) { 'https://test-host' }
  let(:user_key) { 'fs_user_id' }
  let(:user_value) { 'test-user-value' }
  let(:api_key) { 'test-api-key' }
  let(:segments_to_check) { %w[a b c] }
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
      config = Optimizely::OdpConfig.new

      api_manager = Optimizely::ZaiusGraphQLApiManager.new
      segment_manager = Optimizely::OdpSegmentManager.new(0, 0, config, api_manager, spy_logger)

      expect(segment_manager.segments_cache).to be_a Optimizely::LRUCache
      expect(segment_manager.odp_config).to be config
      expect(segment_manager.zaius_manager).to be api_manager
      expect(segment_manager.logger).to be spy_logger

      segment_manager = Optimizely::OdpSegmentManager.new(0, 0, config)
      expect(segment_manager.logger).to be_a Optimizely::NoOpLogger
      expect(segment_manager.zaius_manager).to be_a Optimizely::ZaiusGraphQLApiManager
    end
  end

  describe '#fetch_qualified_segments' do
    it 'should return segments successfully' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .with({headers: {'x-api-key': api_key}, body: {
                'query' => %'query {customer(#{user_key}: "#{user_value}")' \
                "{audiences(subset:#{segments_to_check}) {edges {node {name state}}}}}"
              }})
        .to_return(status: 200, body: good_response_data)

      odp_config = Optimizely::OdpConfig.new(api_key, api_host, segments_to_check)
      segment_manager = Optimizely::OdpSegmentManager.new(1000, 1000, odp_config, nil, spy_logger)
      segment_request = Optimizely::OdpSegmentRequest.new(user_key, user_value, [])

      expect(segment_manager.zaius_manager).not_to receive(:log_failure)

      segment_manager.fetch_qualified_segments(segment_request)

      expect(segment_request.wait_for_segments).to match_array(%w[a b])
      expect(spy_logger).not_to have_received(:log)
    end

    it 'should return empty array with no segments to check' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: good_response_data)

      odp_config = Optimizely::OdpConfig.new(api_key, api_host, [])
      segment_manager = Optimizely::OdpSegmentManager.new(1000, 1000, odp_config, nil, spy_logger)
      segment_request = Optimizely::OdpSegmentRequest.new(user_key, user_value, [])

      expect(segment_manager.zaius_manager).not_to receive(:log_failure)

      segment_manager.fetch_qualified_segments(segment_request)

      expect(segment_request.wait_for_segments).to match_array([])
      expect(spy_logger).not_to have_received(:log)
    end

    it 'should return success with cache miss' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: good_response_data)

      odp_config = Optimizely::OdpConfig.new(api_key, api_host, %w[a b c])
      segment_manager = Optimizely::OdpSegmentManager.new(1000, 1000, odp_config, nil, spy_logger)

      expect(segment_manager.zaius_manager).not_to receive(:log_failure)

      cache_key = segment_manager.send(:make_cache_key, user_key, '123')
      segment_manager.segments_cache.save(cache_key, %w[d])

      segment_request = Optimizely::OdpSegmentRequest.new(user_key, user_value, [])

      segment_manager.fetch_qualified_segments(segment_request)

      expect(segment_request.wait_for_segments).to match_array(%w[a b])
      actual_cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      expect(segment_manager.segments_cache.lookup(actual_cache_key)).to match_array(%w[a b])
      expect(spy_logger).not_to have_received(:log)
    end

    it 'should return success with cache hit' do
      odp_config = Optimizely::OdpConfig.new
      odp_config.update(api_key, api_host, %w[a b c])
      segment_manager = Optimizely::OdpSegmentManager.new(1000, 1000, odp_config, nil, spy_logger)

      expect(segment_manager.zaius_manager).not_to receive(:log_failure)

      cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      segment_manager.segments_cache.save(cache_key, %w[c])

      segment_request = Optimizely::OdpSegmentRequest.new(user_key, user_value, [])

      segment_manager.fetch_qualified_segments(segment_request)

      expect(segment_request.wait_for_segments).to match_array(%w[c])
      expect(spy_logger).not_to have_received(:log)
    end

    it 'should return nil and log error with missing api_host/api_key' do
      odp_config = Optimizely::OdpConfig.new

      segment_manager = Optimizely::OdpSegmentManager.new(1000, 1000, odp_config, nil, spy_logger)
      segment_request = Optimizely::OdpSegmentRequest.new(user_key, user_value, [])

      segment_manager.fetch_qualified_segments(segment_request)

      expect(segment_request.wait_for_segments).to be_nil
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, 'api_key/api_host not defined')
    end

    it 'should return nil with network error' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 500, body: '{}')

      odp_config = Optimizely::OdpConfig.new(api_key, api_host, segments_to_check)
      segment_manager = Optimizely::OdpSegmentManager.new(1000, 1000, odp_config)
      segment_request = Optimizely::OdpSegmentRequest.new(user_key, user_value, [])

      expect(segment_manager.zaius_manager).to receive(:log_failure)

      segment_manager.fetch_qualified_segments(segment_request)

      expect(segment_request.wait_for_segments).to be_nil
    end

    it 'should return non cached value with ignore cache' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: good_response_data)

      odp_config = Optimizely::OdpConfig.new(api_key, api_host, %w[a b c])
      segment_manager = Optimizely::OdpSegmentManager.new(1000, 1000, odp_config, nil, spy_logger)

      expect(segment_manager.zaius_manager).not_to receive(:log_failure)

      cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      segment_manager.segments_cache.save(cache_key, %w[d])

      segment_request = Optimizely::OdpSegmentRequest.new(user_key, user_value, [Optimizely::OptimizelySegmentOption::IGNORE_CACHE])

      segment_manager.fetch_qualified_segments(segment_request)

      expect(segment_request.wait_for_segments).to match_array(%w[a b])
      expect(segment_manager.segments_cache.lookup(cache_key)).to match_array(%w[d])
      expect(spy_logger).not_to have_received(:log)
    end

    it 'should reset cache and return non cached value with reset cache' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: good_response_data)

      odp_config = Optimizely::OdpConfig.new(api_key, api_host, %w[a b c])
      segment_manager = Optimizely::OdpSegmentManager.new(1000, 1000, odp_config, nil, spy_logger)

      expect(segment_manager.zaius_manager).not_to receive(:log_failure)

      cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      segment_manager.segments_cache.save(cache_key, %w[d])
      segment_manager.segments_cache.save('123', %w[c d])

      segment_request = Optimizely::OdpSegmentRequest.new(user_key, user_value, [Optimizely::OptimizelySegmentOption::RESET_CACHE])

      segment_manager.fetch_qualified_segments(segment_request)

      expect(segment_request.wait_for_segments).to match_array(%w[a b])
      expect(segment_manager.segments_cache.lookup(cache_key)).to match_array(%w[a b])
      expect(segment_manager.segments_cache.instance_variable_get('@map').length).to be 1
    end

    it 'should make correct cache key' do
      segment_manager = Optimizely::OdpSegmentManager.new(1000, 1000, nil)
      cache_key = segment_manager.send(:make_cache_key, user_key, user_value)
      expect(cache_key).to be == "#{user_key}-$-#{user_value}"
    end

    it 'should process all segment requests quickly' do
      mutex = Mutex.new
      results = []
      odp_config = Optimizely::OdpConfig.new(api_key, api_host, segments_to_check)

      segment_manager = Optimizely::OdpSegmentManager.new(0, 0, odp_config, nil)

      allow(segment_manager.zaius_manager).to receive(:fetch_segments) do
        # simulate slow REST query
        sleep(1)
        %w[a b]
      end
      expect(segment_manager.zaius_manager).not_to receive(:log_failure)

      thread_count = 1000
      threads = []

      started = Time.now
      thread_count.times do
        threads << Thread.new do
          user_key = rand(1..1000).to_s
          user_value = rand(1..1000).to_s
          segment_request = Optimizely::OdpSegmentRequest.new(user_key, user_value, [Optimizely::OptimizelySegmentOption::IGNORE_CACHE])

          segment_manager.fetch_qualified_segments(segment_request)
          response = segment_request.wait_for_segments
          expect(response).to match_array(%w[a b])

          mutex.synchronize do
            results.push(response)
          end
        end
      end

      threads.each(&:join)

      expect(results.length).to be == thread_count
      expect(results).to all(match_array(%w[a b]))
      expect(Time.now - started).to be < 10
    end
  end
end
