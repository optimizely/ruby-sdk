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
module Optimizely
  class Decision
    attr_reader :campaign_id, :experiment_id, :variation_id, :metadata

    def initialize(campaign_id:, experiment_id:, variation_id:, metadata:)
      @campaign_id = campaign_id
      @experiment_id = experiment_id
      @variation_id = variation_id
      @metadata = metadata
    end

    def as_json
      {
        campaign_id: @campaign_id,
        experiment_id: @experiment_id,
        variation_id: @variation_id,
        metadata: @metadata
      }
    end
  end
end
