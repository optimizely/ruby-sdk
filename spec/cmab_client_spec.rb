# frozen_string_literal: true

#
#    Copyright 2025 Optimizely and contributors
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
require 'spec_helper'
require 'optimizely/logger'
require 'optimizely/cmab/cmab_client'
require 'webmock/rspec'

describe Optimizely::DefaultCmabClient do
  let(:spy_logger) { spy('logger') }
  let(:retry_config) { Optimizely::CmabRetryConfig.new(max_retries: 3, retry_delay: 0.01, max_backoff: 1, backoff_multiplier: 2) }
  let(:rule_id) { 'test_rule' }
  let(:user_id) { 'user123' }
  let(:attributes) { {'attr1': 'value1', 'attr2': 'value2'} }
  let(:cmab_uuid) { 'uuid-1234' }
  let(:expected_url) { "https://prediction.cmab.optimizely.com/predict/#{rule_id}" }
  let(:expected_body_for_webmock) do
    {
      instances: [{
        visitorId: user_id,
        experimentId: rule_id,
        attributes: [
          {'id' => 'attr1', 'value' => 'value1', 'type' => 'custom_attribute'},
          {'id' => 'attr2', 'value' => 'value2', 'type' => 'custom_attribute'}
        ],
        cmabUUID: cmab_uuid
      }]
    }.to_json
  end
  let(:expected_headers) { {'Content-Type' => 'application/json'} }

  before do
    allow(Kernel).to receive(:sleep)
    WebMock.disable_net_connect!
  end

  after do
    RSpec::Mocks.space.proxy_for(spy_logger).reset
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  context 'when client is configured without retries' do
    let(:client) { described_class.new(nil, Optimizely::CmabRetryConfig.new(max_retries: 0), spy_logger) }

    it 'should return the variation id on success' do
      WebMock.stub_request(:post, expected_url)
             .with(body: expected_body_for_webmock, headers: expected_headers)
             .to_return(status: 200, body: {'predictions' => [{'variationId' => 'abc123'}]}.to_json, headers: {'Content-Type' => 'application/json'})

      result = client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)

      expect(result).to eq('abc123')
      expect(WebMock).to have_requested(:post, expected_url)
                     .with(body: expected_body_for_webmock, headers: expected_headers).once
      expect(Kernel).not_to have_received(:sleep)
    end

    it 'should return HTTP exception' do
      WebMock.stub_request(:post, expected_url)
             .with(body: expected_body_for_webmock, headers: expected_headers)
             .to_raise(StandardError.new('Connection error'))

      expect do
        client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      end.to raise_error(Optimizely::CmabFetchError, /Connection error/)

      expect(WebMock).to have_requested(:post, expected_url)
                     .with(body: expected_body_for_webmock, headers: expected_headers).once
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, a_string_including('Connection error'))
      expect(Kernel).not_to have_received(:sleep)
    end

    it 'should not return 200 status' do
      WebMock.stub_request(:post, expected_url)
             .with(body: expected_body_for_webmock, headers: expected_headers)
             .to_return(status: 500)

      expect do
        client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      end.to raise_error(Optimizely::CmabFetchError, /500/)

      expect(WebMock).to have_requested(:post, expected_url)
                     .with(body: expected_body_for_webmock, headers: expected_headers).once
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, a_string_including('500'))
      expect(Kernel).not_to have_received(:sleep)
    end

    it 'should return invalid json' do
      WebMock.stub_request(:post, expected_url)
             .with(body: expected_body_for_webmock, headers: expected_headers)
             .to_return(status: 200, body: 'this is not json', headers: {'Content-Type' => 'text/plain'})

      expect do
        client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      end.to raise_error(Optimizely::CmabInvalidResponseError, /Invalid CMAB fetch response/)

      expect(WebMock).to have_requested(:post, expected_url)
                     .with(body: expected_body_for_webmock, headers: expected_headers).once
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, a_string_including('Invalid CMAB fetch response'))
      expect(Kernel).not_to have_received(:sleep)
    end

    it 'should return invalid response structure' do
      WebMock.stub_request(:post, expected_url)
             .with(body: expected_body_for_webmock, headers: expected_headers)
             .to_return(status: 200, body: {'no_predictions' => []}.to_json, headers: {'Content-Type' => 'application/json'})

      expect do
        client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      end.to raise_error(Optimizely::CmabInvalidResponseError, /Invalid CMAB fetch response/)

      expect(WebMock).to have_requested(:post, expected_url)
                     .with(body: expected_body_for_webmock, headers: expected_headers).once
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, a_string_including('Invalid CMAB fetch response'))
      expect(Kernel).not_to have_received(:sleep)
    end
  end

  context 'when client is configured with retries' do
    let(:client_with_retry) { described_class.new(nil, retry_config, spy_logger) }

    it 'should return the variation id on first try' do
      WebMock.stub_request(:post, expected_url)
             .with(body: expected_body_for_webmock, headers: expected_headers)
             .to_return(status: 200, body: {'predictions' => [{'variationId' => 'abc123'}]}.to_json, headers: {'Content-Type' => 'application/json'})

      result = client_with_retry.fetch_decision(rule_id, user_id, attributes, cmab_uuid)

      expect(result).to eq('abc123')
      expect(WebMock).to have_requested(:post, expected_url)
                     .with(body: expected_body_for_webmock, headers: expected_headers).once
      expect(Kernel).not_to have_received(:sleep)
    end

    it 'should return the variation id on third try' do
      WebMock.stub_request(:post, expected_url)
             .with(body: expected_body_for_webmock, headers: expected_headers)
             .to_return({status: 500},
                        {status: 500},
                        {status: 200, body: {'predictions' => [{'variationId' => 'xyz456'}]}.to_json, headers: {'Content-Type' => 'application/json'}})

      result = client_with_retry.fetch_decision(rule_id, user_id, attributes, cmab_uuid)

      expect(result).to eq('xyz456')
      expect(WebMock).to have_requested(:post, expected_url)
                     .with(body: expected_body_for_webmock, headers: expected_headers).times(3)

      expect(spy_logger).to have_received(:log).with(Logger::INFO, 'Retrying CMAB request (attempt 1) after 0.01 seconds...').once
      expect(spy_logger).to have_received(:log).with(Logger::INFO, 'Retrying CMAB request (attempt 2) after 0.02 seconds...').once
      expect(spy_logger).not_to have_received(:log).with(Logger::INFO, a_string_including('Retrying CMAB request (attempt 3)'))

      expect(Kernel).to have_received(:sleep).with(0.01).once
      expect(Kernel).to have_received(:sleep).with(0.02).once
      expect(Kernel).not_to have_received(:sleep).with(0.08)
    end

    it 'should exhaust all retry attempts' do
      WebMock.stub_request(:post, expected_url)
             .with(body: expected_body_for_webmock, headers: expected_headers)
             .to_return({status: 500},
                        {status: 500},
                        {status: 500},
                        {status: 500})

      expect do
        client_with_retry.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      end.to raise_error(Optimizely::CmabFetchError)

      expect(WebMock).to have_requested(:post, expected_url)
                     .with(body: expected_body_for_webmock, headers: expected_headers).times(4)

      expect(spy_logger).to have_received(:log).with(Logger::INFO, 'Retrying CMAB request (attempt 1) after 0.01 seconds...').once
      expect(spy_logger).to have_received(:log).with(Logger::INFO, 'Retrying CMAB request (attempt 2) after 0.02 seconds...').once
      expect(spy_logger).to have_received(:log).with(Logger::INFO, 'Retrying CMAB request (attempt 3) after 0.08 seconds...').once

      expect(Kernel).to have_received(:sleep).with(0.01).once
      expect(Kernel).to have_received(:sleep).with(0.02).once
      expect(Kernel).to have_received(:sleep).with(0.08).once

      expect(spy_logger).to have_received(:log).with(Logger::ERROR, a_string_including('Max retries exceeded for CMAB request'))
    end
  end
end
