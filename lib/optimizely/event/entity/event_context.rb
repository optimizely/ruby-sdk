# frozen_string_literal: true

#
#    Copyright 2019, Optimizely and contributors
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
module Optimizely
  class EventContext
    attr_reader :account_id, :project_id, :anonymize_ip, :revision, :client_name,
                :client_version

    def initialize(
      account_id:,
      project_id:,
      anonymize_ip:,
      revision:,
      client_name:,
      client_version:,
      region:
    )
      @account_id = account_id
      @project_id = project_id
      @anonymize_ip = anonymize_ip
      @revision = revision
      @client_name = client_name
      @client_version = client_version
      @region = region
    end

    def as_json
      {
        account_id: @account_id,
        project_id: @project_id,
        anonymize_ip: @anonymize_ip,
        revision: @revision,
        client_name: @client_name,
        client_version: @client_version,
        region: @region
      }
    end
  end
end
