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

describe Optimizely::DefaultCmabClient do
  let(:spy_logger) { spy('logger') }
  let(:rule_id) { 'test_rule' }
  let(:user_id) { 'user123' }
  let(:attributes) { {'attr1': 'value1', 'attr2': 'value2'} }
  let(:cmab_uuid) { 'uuid-1234' }
  let(:expected_url) { "https://prediction.cmab.optimizely.com/predict/#{rule_id}" }
  let(:expected_body) do
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
    }
  end
  let(:expected_headers) { {'Content-Type' => 'application/json'} }

  before do
    allow(Kernel).to receive(:sleep)
  end

  after do
    RSpec::Mocks.space.proxy_for(spy_logger).reset
  end

  context 'when client is configured without retries' do
    let(:mock_http_client) { double('http_client') }
    let(:client) { described_class.new(mock_http_client, nil, spy_logger) }

    it 'should return the variation id on success' do
      mock_response = double('response', status_code: 200, json: {'predictions' => [{'variationId' => 'abc123'}]})
      allow(mock_http_client).to receive(:post).and_return(mock_response)

      result = client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)

      expect(result).to eq('abc123')
      expect(mock_http_client).to have_received(:post).with(
        expected_url,
        hash_including(
          json: expected_body,
          headers: expected_headers,
          timeout: 10
        )
      ).once
      expect(Kernel).not_to have_received(:sleep)
    end

    it 'should return HTTP exception' do
      allow(mock_http_client).to receive(:post).and_raise(StandardError.new('Connection error'))

      expect do
        client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      end.to raise_error(Optimizely::CmabFetchError, /Connection error/)

      expect(mock_http_client).to have_received(:post).once
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, a_string_including('Connection error'))
      expect(Kernel).not_to have_received(:sleep)
    end

    it 'should not return 200 status' do
      mock_response = double('response', status_code: 500, json: nil)
      allow(mock_http_client).to receive(:post).and_return(mock_response)

      expect do
        client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      end.to raise_error(Optimizely::CmabFetchError, /500/)

      expect(mock_http_client).to have_received(:post).with(
        expected_url,
        hash_including(
          json: expected_body,
          headers: expected_headers,
          timeout: 10
        )
      ).once
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, a_string_including('500'))
      expect(Kernel).not_to have_received(:sleep)
    end

    it 'should return invalid json' do
      mock_response = double('response', status_code: 200)
      allow(mock_response).to receive(:json).and_raise(JSON::ParserError.new('Expecting value'))
      allow(mock_http_client).to receive(:post).and_return(mock_response)

      expect do
        client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      end.to raise_error(Optimizely::CmabInvalidResponseError, /Invalid CMAB fetch response/)

      expect(mock_http_client).to have_received(:post).with(
        expected_url,
        hash_including(
          json: expected_body,
          headers: expected_headers,
          timeout: 10
        )
      ).once
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, a_string_including('Invalid CMAB fetch response'))
      expect(Kernel).not_to have_received(:sleep)
    end

    it 'should return invalid response structure' do
      mock_response = double('response', status_code: 200, json: {'no_predictions' => []})
      allow(mock_http_client).to receive(:post).and_return(mock_response)

      expect do
        client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      end.to raise_error(Optimizely::CmabInvalidResponseError, /Invalid CMAB fetch response/)

      expect(mock_http_client).to have_received(:post).with(
        expected_url,
        hash_including(
          json: expected_body,
          headers: expected_headers,
          timeout: 10
        )
      ).once
      expect(spy_logger).to have_received(:log).with(Logger::ERROR, a_string_including('Invalid CMAB fetch response'))
      expect(Kernel).not_to have_received(:sleep)
    end
  end

  context 'when client is configured with retries' do
    let(:mock_http_client) { double('http_client') } # Fresh double for this context
    let(:retry_config) { Optimizely::CmabRetryConfig.new(max_retries: 3, retry_delay: 0.01, max_backoff: 1, backoff_multiplier: 2) }
    let(:client_with_retry) { described_class.new(mock_http_client, retry_config, spy_logger) }

    it 'should return the variation id on first try with retry config but no retry needed' do
      mock_response = double('response', status_code: 200, json: {'predictions' => [{'variationId' => 'abc123'}]})
      allow(mock_http_client).to receive(:post).and_return(mock_response)

      result = client_with_retry.fetch_decision(rule_id, user_id, attributes, cmab_uuid)

      expect(result).to eq('abc123')
      expect(mock_http_client).to have_received(:post).with(
        expected_url,
        hash_including(
          json: expected_body,
          headers: expected_headers,
          timeout: 10
        )
      ).once
      expect(Kernel).not_to have_received(:sleep)
    end

    it 'should return the variation id on third try' do
      failure_response = double('response', status_code: 500)
      success_response = double('response', status_code: 200, json: {'predictions' => [{'variationId' => 'xyz456'}]})

      # Use a sequence to control responses
      allow(mock_http_client).to receive(:post).and_return(failure_response, failure_response, success_response)

      result = client_with_retry.fetch_decision(rule_id, user_id, attributes, cmab_uuid)

      expect(result).to eq('xyz456')
      expect(mock_http_client).to have_received(:post).exactly(3).times

      expect(spy_logger).to have_received(:log).with(Logger::INFO, 'Retrying CMAB request (attempt 1) after 0.01 seconds...').once
      expect(spy_logger).to have_received(:log).with(Logger::INFO, 'Retrying CMAB request (attempt 2) after 0.02 seconds...').once
      expect(spy_logger).not_to have_received(:log).with(Logger::INFO, a_string_including('Retrying CMAB request (attempt 3)'))

      expect(Kernel).to have_received(:sleep).with(0.01).once
      expect(Kernel).to have_received(:sleep).with(0.02).once
      expect(Kernel).not_to have_received(:sleep).with(0.04)
      expect(Kernel).not_to have_received(:sleep).with(0.08)
    end

    it 'should exhaust all retry attempts' do
      failure_response = double('response', status_code: 500)

      # All attempts fail
      allow(mock_http_client).to receive(:post).and_return(failure_response, failure_response, failure_response, failure_response)

      expect do
        client_with_retry.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
      end.to raise_error(Optimizely::CmabFetchError)

      expect(mock_http_client).to have_received(:post).exactly(4).times

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
