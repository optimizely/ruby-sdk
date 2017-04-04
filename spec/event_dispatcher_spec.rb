#
#    Copyright 2016-2017, Optimizely and contributors
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
require 'webmock'
require 'optimizely/event_builder'
require 'optimizely/event_dispatcher'

describe Optimizely::EventDispatcher do
  before(:context) do
    @url = 'https://www.optimizely.com'
    @params = {
      'a' => '111001',
      'n' => 'test_event',
      'g' => '111028',
      'u' => 'test_user',
    }
    @post_headers = {'Content-Type' => 'application/json'}
  end

  before(:example) do
    @event_dispatcher = Optimizely::EventDispatcher.new
  end

  it 'should properly dispatch V2 (POST) events' do
    stub_request(:post, @url)
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)
    @event_dispatcher.dispatch_event(event)

    expect(a_request(:post, @url).
      with(:body => @params, :headers => @post_headers)).to have_been_made.once
  end

  it 'should properly dispatch V2 (POST) events with timeout exception' do
    stub_request(:post, @url)
    event = Optimizely::Event.new(:post, @url, @params, @post_headers)
    timeout_error = Timeout::Error.new
    allow(HTTParty).to receive(:post).with(any_args).and_raise(timeout_error)
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

  it 'should properly dispatch V2 (GET) events' do
    get_url = @url + '?a=111001&g=111028&n=test_event&u=test_user'
    stub_request(:get, get_url)
    event = Optimizely::Event.new(:get, get_url, @params, @post_headers)
    timeout_error = Timeout::Error.new
    allow(HTTParty).to receive(:get).with(any_args).and_raise(timeout_error)
    result = @event_dispatcher.dispatch_event(event)

    expect(result).to eq(timeout_error)
  end
end
