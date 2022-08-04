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
require 'optimizely/odp/zaius_graphql_api_manager'

describe Optimizely::ZaiusGraphQlApiManager do
  let(:user_key) { 'vuid' }
  let(:user_value) { 'test-user-value' }
  let(:api_key) { 'test-api-key' }
  let(:api_host) { 'https://test-host' }
  let(:error_handler) { Optimizely::RaiseErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:zaius_manager) { Optimizely::ZaiusGraphQlApiManager.new(logger: spy_logger) }
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
    }
  end
  let(:good_empty_response_data) do
    {
      data: {
        customer: {
          audiences: {
            edges: []
          }
        }
      }
    }
  end
  let(:invalid_identifier_response_data) do
    {
      errors: [
        {
          message: "Exception while fetching data (/customer) :\
         java.lang.RuntimeException: could not resolve _fs_user_id = asdsdaddddd",
          locations: [
            {
              line: 2,
              column: 3
            }
          ],
          path: [
            'customer'
          ],
          extensions: {
            classification: 'InvalidIdentifierException'
          }
        }
      ],
      data: {
        customer: nil
      }
    }
  end
  let(:node_missing_response_data) do
    {
      data: {
        customer: {
          audiences: {
            edges: [
              {}
            ]
          }
        }
      }
    }
  end
  let(:mixed_missing_keys_response_data) do
    {
      data: {
        customer: {
          audiences: {
            edges: [
              {
                node: {
                  state: 'qualified'
                }
              },
              {
                node: {
                  name: 'a'
                }
              },
              {
                "other-name": {
                  name: 'a',
                  state: 'qualified'
                }
              }
            ]
          }
        }
      }
    }
  end
  let(:other_exception_response_data) do
    {
      errors: [
        {
          message: "Exception while fetching data (/customer) :\
           java.lang.RuntimeException: could not resolve _fs_user_id = asdsdaddddd",
          extensions: {
            classification: 'TestExceptionClass'
          }
        }
      ],
      data: {
        customer: nil
      }
    }
  end
  let(:bad_response_data) { {data: {}} }
  let(:name_invalid_response_data) do
    '{
      "data": {
        "customer": {
            "audiences": {
              "edges": [
                {
                  "node": {
                    "name": "a":::invalid-part-here:::,
                    "state": "qualified",
                    "description": "qualifed sample 1"
                }
              }
            ]
          }
        }
      }
    }'
  end
  let(:invalid_edges_key_response_data) do
    {
      data: {
        customer: {
          audiences: {
            invalid_test_key: [
              {
                node: {
                  name: 'a',
                  state: 'qualified',
                  description: 'qualifed sample 1'
                }
              }
            ]
          }
        }
      }
    }
  end
  let(:invalid_key_for_error_response_data) do
    {
      errors: [
        {
          message: "Exception while fetching data (/customer) :\
             java.lang.RuntimeException: could not resolve _fs_user_id = asdsdaddddd",
          locations: [
            {
              line: 2,
              column: 3
            }
          ],
          path: [
            'customer'
          ],
          invalid_test_key: {
            classification: 'InvalidIdentifierException'
          }
        }
      ],
      data: {
        customer: nil
      }
    }
  end
  describe '.fetch_segments' do
    it 'should get qualified segments when valid segments are given' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .with(
          headers: {'content-type': 'application/json', 'x-api-key': api_key},
          body: {
            query: %'query {customer(#{user_key}: "#{user_value}")' \
            '{audiences(subset:["a", "b", "c"]) {edges {node {name state}}}}}'
          }
        )
        .to_return(status: 200, body: good_response_data.to_json)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b c])
      expect(segments).to match_array %w[a b]
    end

    it 'should get empty array when empty array is given' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: good_empty_response_data.to_json)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, [])
      expect(segments).to match_array []
    end

    it 'should log error and return nil when response is missing node' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: node_missing_response_data.to_json)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (decode error).'
      )
    end

    it 'should log error and return nil when response keys are incorrect' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: mixed_missing_keys_response_data.to_json)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (decode error).'
      )
    end

    it 'should log error and return nil with invalid identifier exception' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: invalid_identifier_response_data.to_json)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (invalid identifier).'
      )
    end

    it 'should log error and return nil with other exception' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: other_exception_response_data.to_json)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (TestExceptionClass).'
      )
    end

    it 'should log error and return nil with bad response data' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: bad_response_data.to_json)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (decode error).'
      )
    end

    it 'should log error and return nil with invalid name' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: name_invalid_response_data)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (JSON decode error).'
      )
    end

    it 'should log error and return nil with invalid key' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: invalid_edges_key_response_data.to_json)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (decode error).'
      )
    end

    it 'should log error and return nil with invalid key in error body' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 200, body: invalid_key_for_error_response_data.to_json)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (decode error).'
      )
    end

    it 'should log error and return nil with network error' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .and_raise(SocketError)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (network error).'
      )

      expect(spy_logger).to have_received(:log).once.with(
        Logger::DEBUG,
        'GraphQL download failed: Exception from WebMock'
      )
    end

    it 'should log error and return nil with http status 400' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 400)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (400).'
      )
    end

    it 'should log error and return nil with http status 500' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .to_return(status: 500)

      segments = zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b])
      expect(segments).to be_nil

      expect(spy_logger).to have_received(:log).once.with(
        Logger::ERROR,
        'Audience segments fetch failed (500).'
      )
    end

    it 'should create correct subset filter' do
      stub_request(:post, "#{api_host}/v3/graphql")
        .with(
          body: {
            query: %'query {customer(#{user_key}: "#{user_value}")' \
            '{audiences(subset:[]) {edges {node {name state}}}}}'
          }
        )
      zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, nil)

      stub_request(:post, "#{api_host}/v3/graphql")
        .with(
          body: {
            query: %'query {customer(#{user_key}: "#{user_value}")' \
            '{audiences(subset:[]) {edges {node {name state}}}}}'
          }
        )
      zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, [])

      stub_request(:post, "#{api_host}/v3/graphql")
        .with(
          body: {
            query: %'query {customer(#{user_key}: "#{user_value}")' \
            '{audiences(subset:["a"]) {edges {node {name state}}}}}'
          }
        )
      zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a])

      stub_request(:post, "#{api_host}/v3/graphql")
        .with(
          body: {
            query: %'query {customer(#{user_key}: "#{user_value}")' \
            '{audiences(subset:["a", "b", "c"]) {edges {node {name state}}}}}'
          }
        )
      zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, %w[a b c])
    end

    it 'should pass the proxy config that is passed in' do
      allow(Optimizely::Helpers::HttpUtils).to receive(:make_request).and_raise(SocketError)
      stub_request(:post, "#{api_host}/v3/graphql")

      zaius_manager = Optimizely::ZaiusGraphQlApiManager.new(logger: spy_logger, proxy_config: :proxy_config)
      zaius_manager.fetch_segments(api_key, api_host, user_key, user_value, [])
      expect(Optimizely::Helpers::HttpUtils).to have_received(:make_request).with(anything, anything, anything, anything, anything, :proxy_config)
    end
  end
end
