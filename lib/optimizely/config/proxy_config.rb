# frozen_string_literal: true

#    Copyright 2020, Optimizely and contributors
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

module Optimizely
  class ProxyConfig
    attr_reader :host, :port, :username, :password

    def initialize(host, port = nil, username = nil, password = nil)
      # host - DNS name or IP address of proxy
      # port - port to use to acess the proxy
      # username - username if authorization is required
      # password - password if authorization is required
      @host = host
      @port = port
      @username = username
      @password = password
    end
  end
end
