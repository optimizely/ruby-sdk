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
  end

  before(:example) do
    @event_dispatcher = Optimizely::EventDispatcher.new
  end

  it 'should properly dispatch V1 (GET) events' do
    stub_request(:get, @url).with(:query => @params)
    event = Optimizely::Event.new(:get, @url, @params)
    @event_dispatcher.dispatch_event(event)

    expect(a_request(:get, @url).with(:query => @params)).to have_been_made.once
  end

  it 'should properly dispatch V2 (POST) events' do
    stub_request(:post, @url)
    event = Optimizely::Event.new(:post, @url, @params)
    @event_dispatcher.dispatch_event(event)

    expect(a_request(:post, @url).
      with(:body => @params, :headers => {'Content-Type' => 'application/json'})).to have_been_made.once
  end
end
