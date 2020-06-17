# frozen_string_literal: true

#
#    Copyright 2019-2020, Optimizely and contributors
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
require 'optimizely/config/proxy_config'

describe Optimizely::ProxyConfig do
  let(:host) { 'host' }
  let(:port) { 1234 }
  let(:username) { 'username' }
  let(:password) { 'password' }

  describe '#initialize' do
    it 'defines getters for host, port, username, and password' do
      proxy_config = described_class.new(host, port, username, password)

      expect(proxy_config.host).to eq(host)
      expect(proxy_config.port).to eq(port)
      expect(proxy_config.username).to eq(username)
      expect(proxy_config.password).to eq(password)
    end

    it 'sets port, username, and password to nil if they are not passed in' do
      proxy_config = described_class.new(host)
      expect(proxy_config.port).to eq(nil)
      expect(proxy_config.username).to eq(nil)
      expect(proxy_config.password).to eq(nil)
    end
  end
end
