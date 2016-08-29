require 'spec_helper'
require 'webmock'
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

  it 'should fire off GET request with provided URL and params' do
    stub_request(:get, @url).with(:query => @params)
    @event_dispatcher.dispatch_event(@url, @params, :get)

    expect(a_request(:get, @url).with(:query => @params)).to have_been_made.once
  end
end
