# frozen_string_literal: true

#
#    Copyright 2016-2017, 2019-2020, 2022, Optimizely and contributors
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
require 'optimizely/event_dispatcher'
require 'optimizely/exceptions'

describe Optimizely::EventDispatcher do
  let(:error_handler) { spy(Optimizely::NoOpErrorHandler.new) }
  let(:spy_logger) { spy('logger') }
  let(:proxy_config) { nil }

  before(:context) do
    @url = 'https://www.optimizely.com'
    @params = {
      'a' => '111001',
      'n' => 'test_event',
      'g' => '111028',
      'u' => 'test_user'
    }
    @post_headers = {'Content-Type' => 'application/json'}
  end

  before(:example) do
    @event_dispatcher = Optimizely::EventDispatcher.new
    @customized_event_dispatcher = Optimizely::EventDispatcher.new(
      logger: spy_logger, error_handler: error_handler, proxy_config: proxy_config
    )
  end

  context 'passing in proxy config' do
    let(:proxy_config) { double(:proxy_config) }

    it 'should pass the proxy_config to the HttpUtils helper class' do
      event = Optimizely::Event.new(:post, @url, @params, @post_headers)
      # Allow the method to be called (potentially multiple times due to retries)
      allow(Optimizely::Helpers::HttpUtils).to receive(:make_request).with(
        event.url,
        event.http_verb,
        event.params.to_json,
        event.headers,
        Optimizely::Helpers::Constants::EVENT_DISPATCH_CONFIG[:REQUEST_TIMEOUT],
        proxy_config
      ).and_return(double(code: '200'))

      @customized_event_dispatcher.dispatch_event(event)

      # Verify it was called at least once with the correct parameters
      expect(Optimizely::Helpers::HttpUtils).to have_received(:make_request).with(
        event.url,
        event.http_verb,
        event.params.to_json,
        event.headers,
        Optimizely::Helpers::Constants::EVENT_DISPATCH_CONFIG[:REQUEST_TIMEOUT],
        proxy_config
      ).at_least(:once)
    end
  end

  it 'should properly dispatch V2 (POST) events' do
    stub_request(:post, @url)
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)
    @event_dispatcher.dispatch_event(event)

    expect(a_request(:post, @url)
      .with(body: @params, headers: @post_headers)).to have_been_made.once
  end

  it 'should properly dispatch V2 (POST) events to http url' do
    http_url = 'http://www.optimizely.com'
    stub_request(:post, http_url)
    event = Optimizely::Event.new(:post, http_url, @params, @post_headers)
    @event_dispatcher.dispatch_event(event)

    expect(a_request(:post, http_url)
      .with(body: @params, headers: @post_headers)).to have_been_made.once
  end

  it 'should properly dispatch V2 (POST) events with timeout exception' do
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)
    timeout_error = Timeout::Error.new
    stub_request(:post, @url).to_raise(timeout_error)
    result = @event_dispatcher.dispatch_event(event)

    expect(result).to eq(timeout_error)
  end

  it 'should properly dispatch V2 (GET) events' do
    get_url = "#{@url}?a=111001&g=111028&n=test_event&u=test_user"
    stub_request(:get, get_url)
    event = Optimizely::Event.new(:get, get_url, @params, @post_headers)
    @event_dispatcher.dispatch_event(event)

    expect(a_request(:get, get_url)).to have_been_made.once
  end

  it 'should properly dispatch V2 (GET) events with timeout exception' do
    get_url = "#{@url}?a=111001&g=111028&n=test_event&u=test_user"
    event = Optimizely::Event.new(:get, get_url, @params, @post_headers)
    timeout_error = Timeout::Error.new
    stub_request(:get, get_url).to_raise(timeout_error)

    result = @event_dispatcher.dispatch_event(event)

    expect(result).to eq(timeout_error)
  end

  it 'should log and handle Timeout error' do
    get_url = "#{@url}?a=111001&g=111028&n=test_event&u=test_user"
    event = Optimizely::Event.new(:post, get_url, @params, @post_headers)
    timeout_error = Timeout::Error.new
    stub_request(:post, get_url).to_raise(timeout_error)

    result = @customized_event_dispatcher.dispatch_event(event)

    expect(result).to eq(timeout_error)
    # With retries, this will be logged 3 times (once per attempt)
    expect(spy_logger).to have_received(:log).with(
      Logger::ERROR, 'Request Timed out. Error: Timeout::Error'
    ).exactly(3).times

    expect(error_handler).to have_received(:handle_error).exactly(3).times.with(Timeout::Error)
  end

  it 'should log and handle any standard error' do
    get_url = "#{@url}?a=111001&g=111028&n=test_event&u=test_user"
    event = Optimizely::Event.new(:post, get_url, @params, @post_headers)
    stub_request(:post, get_url).to_raise(ArgumentError.new)

    result = @customized_event_dispatcher.dispatch_event(event)

    expect(result).to eq(nil)
    # With retries, this will be logged 3 times (once per attempt)
    expect(spy_logger).to have_received(:log).with(
      Logger::ERROR, 'Event failed to dispatch. Error: ArgumentError'
    ).exactly(3).times

    expect(error_handler).to have_received(:handle_error).exactly(3).times.with(ArgumentError)
  end

  it 'should log and handle any response with status code 4xx' do
    stub_request(:post, @url).to_return(status: 499)
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)

    @customized_event_dispatcher.dispatch_event(event)

    expect(spy_logger).to have_received(:log).with(
      Logger::ERROR, 'Event failed to dispatch with response code: 499'
    ).once

    error = Optimizely::HTTPCallError.new('HTTP Client Error: 499')
    expect(error_handler).to have_received(:handle_error).once.with(error)
  end

  it 'should log and handle any response with status code 5xx' do
    stub_request(:post, @url).to_return(status: 500)
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)

    @customized_event_dispatcher.dispatch_event(event)

    # With retries, this will be logged 3 times (once per attempt)
    expect(spy_logger).to have_received(:log).with(
      Logger::ERROR, 'Event failed to dispatch with response code: 500'
    ).exactly(3).times

    error = Optimizely::HTTPCallError.new('HTTP Server Error: 500')
    expect(error_handler).to have_received(:handle_error).exactly(3).times.with(error)
  end

  it 'should do nothing on response with status code 3xx' do
    stub_request(:post, @url).to_return(status: 399)
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)

    @customized_event_dispatcher.dispatch_event(event)

    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'event successfully sent with response code 399')
    expect(error_handler).to_not have_received(:handle_error)
  end

  it 'should do nothing on response with status code 600' do
    stub_request(:post, @url).to_return(status: 600)
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)

    @customized_event_dispatcher.dispatch_event(event)

    expect(spy_logger).to have_received(:log).with(Logger::DEBUG, 'event successfully sent with response code 600')
    expect(error_handler).not_to have_received(:handle_error)
  end

  context 'retry logic with exponential backoff' do
    it 'should retry on 5xx errors with exponential backoff' do
      stub_request(:post, @url).to_return(status: 500).times(2).then.to_return(status: 200)
      event = Optimizely::Event.new(:post, @url, @params, @post_headers)

      start_time = Time.now
      @customized_event_dispatcher.dispatch_event(event)
      elapsed_time = Time.now - start_time

      # Should make 3 requests total (1 initial + 2 retries)
      expect(a_request(:post, @url)).to have_been_made.times(3)

      # Should have delays: 200ms + 400ms = 600ms minimum
      expect(elapsed_time).to be >= 0.5 # Allow some tolerance

      # Should log retry attempts
      expect(spy_logger).to have_received(:log).with(
        Logger::DEBUG, /Retrying event dispatch/
      ).at_least(:twice)
    end

    it 'should not retry on 4xx client errors' do
      stub_request(:post, @url).to_return(status: 400)
      event = Optimizely::Event.new(:post, @url, @params, @post_headers)

      @customized_event_dispatcher.dispatch_event(event)

      # Should only make 1 request (no retries)
      expect(a_request(:post, @url)).to have_been_made.once

      # Should not log retry attempts
      expect(spy_logger).not_to have_received(:log).with(
        Logger::DEBUG, /Retrying event dispatch/
      )
    end

    it 'should retry on Timeout errors with exponential backoff' do
      stub_request(:post, @url).to_timeout.times(2).then.to_return(status: 200)
      event = Optimizely::Event.new(:post, @url, @params, @post_headers)

      start_time = Time.now
      @customized_event_dispatcher.dispatch_event(event)
      elapsed_time = Time.now - start_time

      # Should make 3 requests total (1 initial + 2 retries)
      expect(a_request(:post, @url)).to have_been_made.times(3)

      # Should have delays: 200ms + 400ms = 600ms minimum
      expect(elapsed_time).to be >= 0.5

      # Should log retry attempts
      expect(spy_logger).to have_received(:log).with(
        Logger::DEBUG, /Retrying event dispatch/
      ).at_least(:twice)
    end

    it 'should retry on standard errors with exponential backoff' do
      stub_request(:post, @url).to_raise(StandardError.new('Network error')).times(2).then.to_return(status: 200)
      event = Optimizely::Event.new(:post, @url, @params, @post_headers)

      start_time = Time.now
      @customized_event_dispatcher.dispatch_event(event)
      elapsed_time = Time.now - start_time

      # Should make 3 requests total (1 initial + 2 retries)
      expect(a_request(:post, @url)).to have_been_made.times(3)

      # Should have delays: 200ms + 400ms = 600ms minimum
      expect(elapsed_time).to be >= 0.5

      # Should log retry attempts
      expect(spy_logger).to have_received(:log).with(
        Logger::DEBUG, /Retrying event dispatch/
      ).at_least(:twice)
    end

    it 'should give up after max retries' do
      stub_request(:post, @url).to_return(status: 500)
      event = Optimizely::Event.new(:post, @url, @params, @post_headers)

      @customized_event_dispatcher.dispatch_event(event)

      # Should make max_retries requests (3)
      expect(a_request(:post, @url)).to have_been_made.times(3)

      # Should log error for each retry
      expect(spy_logger).to have_received(:log).with(
        Logger::ERROR, 'Event failed to dispatch with response code: 500'
      ).exactly(3).times
    end

    it 'should calculate correct exponential backoff intervals' do
      dispatcher = Optimizely::EventDispatcher.new

      # First retry: 200ms
      expect(dispatcher.send(:calculate_retry_interval, 0)).to eq(0.2)

      # Second retry: 400ms
      expect(dispatcher.send(:calculate_retry_interval, 1)).to eq(0.4)

      # Third retry: 800ms
      expect(dispatcher.send(:calculate_retry_interval, 2)).to eq(0.8)

      # Fourth retry: capped at 1s
      expect(dispatcher.send(:calculate_retry_interval, 3)).to eq(1.0)

      # Fifth retry: still capped at 1s
      expect(dispatcher.send(:calculate_retry_interval, 4)).to eq(1.0)
    end
  end
end
