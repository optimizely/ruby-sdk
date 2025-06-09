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
require 'optimizely/cmab/cmab_client'

describe Optimizely::DefaultCmabClient do
  let(:mock_http_client) { double('http_client') }
  let(:mock_logger) { double('logger') }
  let(:retry_config) { Optimizely::CmabRetryConfig.new(max_retries: 3, initial_backoff: 0.01, max_backoff: 1, backoff_multiplier: 2) }
  let(:client) { described_class.new(http_client: mock_http_client, logger: mock_logger, retry_config: nil) }
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
          {id: 'attr1', value: 'value1', type: 'custom_attribute'},
          {id: 'attr2', value: 'value2', type: 'custom_attribute'}
        ],
        cmabUUID: cmab_uuid
      }]
    }
  end
  let(:expected_headers) { {'Content-Type' => 'application/json'} }

  it 'should return the variation id on success without retrying' do
    mock_response = double('response', status_code: 200, json: {'predictions' => [{'variationId': 'abc123'}]})
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
    )
  end

  it 'should return HTTP exception without retrying' do
    allow(mock_http_client).to receive(:post).and_raise(StandardError.new('Connection error'))
    allow(mock_logger).to receive(:error)
    expect do
      client.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
    end.to raise_error(Optimizely::CmabFetchError, /Connection error/)
    expect(mock_http_client).to have_received(:post).once
    expect(mock_logger).to have_received(:error).with(a_string_including('Connection error'))
  end

  it 'should not return 200 status without retrying' do
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
    )
    expect(mock_logger).to have_received(:error).with(a_string_including('500'))
  end

  it 'should return invalid json without retrying' do
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
    )
    expect(mock_logger).to have_received(:error).with(a_string_including('Invalid CMAB fetch response'))
  end

  it 'should return invalid response structure without retrying' do
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
    )
    expect(mock_logger).to have_received(:error).with(a_string_including('Invalid CMAB fetch response'))
  end

  it 'should return the variation id on first try with retry config but no retry needed' do
    client_with_retry = described_class.new(
      http_client: mock_http_client,
      logger: mock_logger,
      retry_config: retry_config
    )

    # Mock successful response
    mock_response = double('response', status_code: 200, json: {'predictions' => [{'variationId': 'abc123'}]})
    allow(mock_http_client).to receive(:post).and_return(mock_response)
    allow_any_instance_of(Object).to receive(:sleep)

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
    expect_any_instance_of(Object).not_to have_received(:sleep)
  end

  it 'should return the variation id on third try with retry config' do
    client_with_retry = described_class.new(
      http_client: mock_http_client,
      logger: mock_logger,
      retry_config: retry_config
    )

    # Create failure and success responses
    failure_response = double('response', status_code: 500)
    success_response = double('response', status_code: 200, json: {'predictions' => [{'variationId': 'xyz456'}]})

    # First two calls fail, third succeeds
    call_sequence = [failure_response, failure_response, success_response]
    allow(mock_http_client).to receive(:post) { call_sequence.shift }

    allow(mock_logger).to receive(:info)
    allow_any_instance_of(Object).to receive(:sleep)

    result = client_with_retry.fetch_decision(rule_id, user_id, attributes, cmab_uuid)

    expect(result).to eq('xyz456')
    expect(mock_http_client).to have_received(:post).exactly(3).times

    # Verify all HTTP calls used correct parameters
    expect(mock_http_client).to have_received(:post).with(
      expected_url,
      hash_including(
        json: expected_body,
        headers: expected_headers,
        timeout: 10
      )
    )

    # Verify retry logging
    expect(mock_logger).to have_received(:info).with('Retrying CMAB request (attempt 1) after 0.01 seconds...')
    expect(mock_logger).to have_received(:info).with('Retrying CMAB request (attempt 2) after 0.02 seconds...')

    # Verify sleep was called with correct backoff times
    expect_any_instance_of(Object).to have_received(:sleep).with(0.01)
    expect_any_instance_of(Object).to have_received(:sleep).with(0.02)
  end

  it 'should exhausts all retry attempts' do
    client_with_retry = described_class.new(
      http_client: mock_http_client,
      logger: mock_logger,
      retry_config: retry_config
    )

    # Create failure response
    failure_response = double('response', status_code: 500)

    # All attempts fail
    allow(mock_http_client).to receive(:post).and_return(failure_response)
    allow(mock_logger).to receive(:info)
    allow(mock_logger).to receive(:error)
    allow_any_instance_of(Object).to receive(:sleep)

    expect do
      client_with_retry.fetch_decision(rule_id, user_id, attributes, cmab_uuid)
    end.to raise_error(Optimizely::CmabFetchError)

    # Verify all attempts were made (1 initial + 3 retries)
    expect(mock_http_client).to have_received(:post).exactly(4).times

    # Verify retry logging
    expect(mock_logger).to have_received(:info).with('Retrying CMAB request (attempt 1) after 0.01 seconds...')
    expect(mock_logger).to have_received(:info).with('Retrying CMAB request (attempt 2) after 0.02 seconds...')
    expect(mock_logger).to have_received(:info).with('Retrying CMAB request (attempt 3) after 0.08 seconds...')

    # Verify sleep was called for each retry
    expect_any_instance_of(Object).to have_received(:sleep).with(0.01)
    expect_any_instance_of(Object).to have_received(:sleep).with(0.02)
    expect_any_instance_of(Object).to have_received(:sleep).with(0.08)

    # Verify final error logging
    expect(mock_logger).to have_received(:error).with(a_string_including('Max retries exceeded for CMAB request'))
  end
end
