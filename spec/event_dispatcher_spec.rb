# frozen_string_literal: true

#
#    Copyright 2016-2017, 2019, Optimizely and contributors
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
      logger: spy_logger, error_handler: error_handler
    )
  end

  it 'should properly dispatch V2 (POST) events' do
    stub_request(:post, @url)
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)
    @event_dispatcher.dispatch_event(event)

    expect(a_request(:post, @url)
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
    get_url = @url + '?a=111001&g=111028&n=test_event&u=test_user'
    stub_request(:get, get_url)
    event = Optimizely::Event.new(:get, get_url, @params, @post_headers)
    @event_dispatcher.dispatch_event(event)

    expect(a_request(:get, get_url)).to have_been_made.once
  end

  it 'should properly dispatch V2 (GET) events with timeout exception' do
    get_url = @url + '?a=111001&g=111028&n=test_event&u=test_user'
    event = Optimizely::Event.new(:get, get_url, @params, @post_headers)
    timeout_error = Timeout::Error.new
    stub_request(:get, get_url).to_raise(timeout_error)

    result = @event_dispatcher.dispatch_event(event)

    expect(result).to eq(timeout_error)
  end

  it 'should log and handle Timeout error' do
    get_url = @url + '?a=111001&g=111028&n=test_event&u=test_user'
    event = Optimizely::Event.new(:post, get_url, @params, @post_headers)
    timeout_error = Timeout::Error.new
    stub_request(:post, get_url).to_raise(timeout_error)

    result = @customized_event_dispatcher.dispatch_event(event)

    expect(result).to eq(timeout_error)
    expect(spy_logger).to have_received(:log).with(
      Logger::ERROR, 'Request Timed out. Error: Timeout::Error'
    ).once

    expect(error_handler).to have_received(:handle_error).once.with(Timeout::Error)
  end

  it 'should log and handle any standard error' do
    get_url = @url + '?a=111001&g=111028&n=test_event&u=test_user'
    event = Optimizely::Event.new(:post, get_url, @params, @post_headers)
    stub_request(:post, get_url).to_raise(ArgumentError.new)

    result = @customized_event_dispatcher.dispatch_event(event)

    expect(result).to eq(nil)
    expect(spy_logger).to have_received(:log).with(
      Logger::ERROR, 'Event failed to dispatch. Error: ArgumentError'
    ).once

    expect(error_handler).to have_received(:handle_error).once.with(ArgumentError)
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

    expect(spy_logger).to have_received(:log).with(
      Logger::ERROR, 'Event failed to dispatch with response code: 500'
    ).once

    error = Optimizely::HTTPCallError.new('HTTP Server Error: 500')
    expect(error_handler).to have_received(:handle_error).once.with(error)
  end

  it 'should do nothing on response with status code 3xx' do
    stub_request(:post, @url).to_return(status: 399)
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)

    response = @customized_event_dispatcher.dispatch_event(event)

    expect(response).to have_received(:log)
    expect(spy_logger).to have_received(:log)
    expect(error_handler).to_not have_received(:handle_error)
  end

  it 'should do nothing on response with status code 600' do
    stub_request(:post, @url).to_return(status: 600)
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)

    response = @customized_event_dispatcher.dispatch_event(event)

    expect(response).to have_received(:log)
    expect(spy_logger).to have_received(:log)
    expect(error_handler).not_to have_received(:handle_error)
  end
end
