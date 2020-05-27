# frozen_string_literal: true

#
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

require 'net/http'

module Optimizely
  module Helpers
    module HttpUtils
      module_function

      def make_request(url, http_method, request_body = nil, headers = {}, read_timeout = nil)
        # makes http/https GET/POST request and returns response

        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)

        http.read_timeout = read_timeout if read_timeout
        http.use_ssl = uri.scheme == 'https'

        if http_method == :get
          request = Net::HTTP::Get.new(uri.request_uri)
        elsif http_method == :post
          request = Net::HTTP::Post.new(uri.request_uri)
          request.body = request_body if request_body
        else
          return nil
        end

        # set headers
        headers&.each do |key, val|
          request[key] = val
        end

        http.request(request)
      end
    end
  end
end
