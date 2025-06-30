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
  class EventBatch
    attr_accessor :account_id, :project_id, :revision, :client_name, :client_version,
                  :anonymize_ip, :enrich_decisions, :visitors

    def as_json
      {
        account_id: @account_id,
        project_id: @project_id,
        revision: @revision,
        client_name: @client_name,
        client_version: @client_version,
        anonymize_ip: @anonymize_ip,
        enrich_decisions: @enrich_decisions,
        visitors: @visitors,
        region: @region
      }
    end

    class Builder
      attr_reader :account_id, :project_id, :revision, :client_name, :client_version,
                  :anonymize_ip, :enrich_decisions, :visitors, :region

      def build
        event_batch = EventBatch.new
        event_batch.account_id = @account_id
        event_batch.project_id = @project_id
        event_batch.revision = @revision
        event_batch.client_name = @client_name
        event_batch.client_version = @client_version
        event_batch.anonymize_ip = @anonymize_ip
        event_batch.enrich_decisions = @enrich_decisions
        event_batch.visitors = @visitors
        event_batch.region = @region
        event_batch
      end

      def with_account_id(account_id)
        @account_id = account_id
      end

      def with_project_id(project_id)
        @project_id = project_id
      end

      def with_revision(revision)
        @revision = revision
      end

      def region(region)
        @region = region
      end

      def with_client_name(client_name)
        @client_name = client_name
      end

      def with_client_version(client_version)
        @client_version = client_version
      end

      def with_anonymize_ip(anonymize_ip)
        @anonymize_ip = anonymize_ip
      end

      def with_enrich_decisions(enrich_decisions)
        @enrich_decisions = enrich_decisions
      end

      def with_visitors(visitors)
        @visitors = visitors
      end
    end
  end
end
