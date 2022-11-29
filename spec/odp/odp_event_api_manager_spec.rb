# frozen_string_literal: true

#
#    Copyright 2022, Optimizely and contributors
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
require 'optimizely/odp/odp_event_api_manager'

describe Optimizely::OdpEventApiManager do
  let(:user_key) { 'vuid' }
  let(:user_value) { 'test-user-value' }
  let(:api_key) { 'test-api-key' }
  let(:api_host) { 'https://test-host.com' }
  let(:spy_logger) { spy('logger') }
  let(:events) do
    [
      {type: 't1', action: 'a1', identifiers: {'id-key-1': 'id-value-1'}, data: {'key-1': 'value1'}},
      {type: 't2', action: 'a2', identifiers: {'id-key-2': 'id-value-2'}, data: {'key-2': 'value2'}}
    ]
  end
  let(:failure_response_data) do
    {
      title: 'Bad Request', status: 400, timestamp: '2022-07-01T20:44:00.945Z',
      detail: {
        invalids: [{event: 0, message: "missing 'type' field"}]
      }
    }.to_json
  end

  describe '.fetch_segments' do
    it 'should send odp events successfully and return false' do
      stub_request(:post, "#{api_host}/v3/events")
        .with(
          headers: {'content-type': 'application/json', 'x-api-key': api_key},
          body: events.to_json
        ).to_return(status: 200)

      api_manager = Optimizely::OdpEventApiManager.new
      expect(spy_logger).not_to receive(:log)
      should_retry = api_manager.send_odp_events(api_key, api_host, events, nil)

      expect(should_retry).to be false
    end

    it 'should return true on network error' do
      allow(Optimizely::Helpers::HttpUtils).to receive(:make_request).and_raise(SocketError)
      api_manager = Optimizely::OdpEventApiManager.new(logger: spy_logger)
      expect(spy_logger).to receive(:log).with(Logger::ERROR, 'ODP event send failed (network error).')

      should_retry = api_manager.send_odp_events(api_key, api_host, events, nil)

      expect(should_retry).to be true
    end

    it 'should return false with 400 error' do
      stub_request(:post, "#{api_host}/v3/events")
        .with(
          body: events.to_json
        ).to_return(status: [400, 'Bad Request'], body: failure_response_data)

      api_manager = Optimizely::OdpEventApiManager.new(logger: spy_logger)
      expect(spy_logger).to receive(:log).with(
        Logger::ERROR, 'ODP event send failed ({"title":"Bad Request","status":400,' \
                       '"timestamp":"2022-07-01T20:44:00.945Z","detail":{"invalids":' \
                       '[{"event":0,"message":"missing \'type\' field"}]}}).'
      )

      should_retry = api_manager.send_odp_events(api_key, api_host, events, nil)

      expect(should_retry).to be false
    end

    it 'should return true with 500 error' do
      stub_request(:post, "#{api_host}/v3/events")
        .with(
          body: events.to_json
        ).to_return(status: [500, 'Internal Server Error'])

      api_manager = Optimizely::OdpEventApiManager.new(logger: spy_logger)
      expect(spy_logger).to receive(:log).with(Logger::ERROR, 'ODP event send failed (500: Internal Server Error).')

      should_retry = api_manager.send_odp_events(api_key, api_host, events, nil)

      expect(should_retry).to be true
    end
  end
end
