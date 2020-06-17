# frozen_string_literal: true

#    Copyright 2016-2017, 2019-2020, Optimizely and contributors
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
#
require 'spec_helper'
#require 'optimizely/helpers/http_utils'
require 'optimizely/config/proxy_config'

describe Optimizely::Helpers::HttpUtils do
  context 'passing in a proxy config' do
    let(:url) { 'https://example.com' }
    let(:http_method) { :get }
    let(:host) { 'host' }
    let(:port) { 1234 }
    let(:username) { 'username' }
    let(:password) { 'password' }
    let(:http_class) { double(:http_class) }
    let(:http) { double(:http) }

    before do
      allow(http_class).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:request)
    end

    context 'with a proxy config that inclues host, port, username, and password' do
      let(:proxy_config) { Optimizely::ProxyConfig.new(host, port, username, password) }
      it 'with a full proxy config, it proxies the web request' do
        expect(Net::HTTP).to receive(:Proxy).with(host, port, username, password).and_return(http_class)
        described_class.make_request(url, http_method, nil, nil, nil, proxy_config)
      end
    end

    context 'with a proxy config that only inclues host' do
      let(:proxy_config) { Optimizely::ProxyConfig.new(host) }
      it 'with a full proxy config, it proxies the web request' do
        expect(Net::HTTP).to receive(:Proxy).with(host, nil, nil, nil).and_return(http_class)
        described_class.make_request(url, http_method, nil, nil, nil, proxy_config)
      end
    end
  end
end
