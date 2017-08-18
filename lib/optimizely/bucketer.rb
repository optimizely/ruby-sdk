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
require 'murmurhash3'
require_relative 'helpers/group'

module Optimizely
  class Bucketer
    # Optimizely bucketing algorithm that evenly distributes visitors.

    BUCKETING_ID_TEMPLATE = '%{user_id}%{entity_id}'
    HASH_SEED = 1
    MAX_HASH_VALUE = 2**32
    MAX_TRAFFIC_VALUE = 10_000
    UNSIGNED_MAX_32_BIT_VALUE = 0xFFFFFFFF

    def initialize(config)
      # Bucketer init method to set bucketing seed and project config data.
      #
      # config - ProjectConfig data to be used in making bucketing decisions.

      @bucket_seed = HASH_SEED
      @config = config
    end

    def bucket(experiment_key, user_id)
      # Determines ID of variation to be shown for a given experiment key and user ID.
      #
      # experiment_key - String Key representing experiment for which visitor is to be bucketed.
      # user_id - String ID for user.
      #
      # Returns String variation ID in which visitor with ID user_id has been placed. Nil if no variation.

      # check if experiment is in a group; if so, check if user is bucketed into specified experiment
      experiment_id = @config.get_experiment_id(experiment_key)
      group_id = @config.get_experiment_group_id(experiment_key)
      if group_id
        group = @config.group_key_map.fetch(group_id)
        if Helpers::Group.random_policy?(group)
          traffic_allocations = group.fetch('trafficAllocation')
          bucketed_experiment_id = find_bucket(user_id, group_id, traffic_allocations)
          # return if the user is not bucketed into any experiment
          unless bucketed_experiment_id
            @config.logger.log(Logger::INFO, "User '#{user_id}' is in no experiment.")
            return nil
          end

          # return if the user is bucketed into a different experiment than the one specified
          if bucketed_experiment_id != experiment_id
            @config.logger.log(
              Logger::INFO,
              "User '#{user_id}' is not in experiment '#{experiment_key}' of group #{group_id}."
            )
            return nil
          end

          # continue bucketing if the user is bucketed into the experiment specified
          @config.logger.log(
            Logger::INFO,
            "User '#{user_id}' is in experiment '#{experiment_key}' of group #{group_id}."
          )
        end
      end

      traffic_allocations = @config.get_traffic_allocation(experiment_key)
      variation_id = find_bucket(user_id, experiment_id, traffic_allocations)
      if variation_id && variation_id != ''
        variation_key = @config.get_variation_key_from_id(experiment_key, variation_id)
        @config.logger.log(
          Logger::INFO,
          "User '#{user_id}' is in variation '#{variation_key}' of experiment '#{experiment_key}'."
        )
        return variation_id
      end

      # Handle the case when the traffic range is empty due to sticky bucketing
      if variation_id == ''
        @config.logger.log(Logger::DEBUG, 'Bucketed into an empty traffic range. Returning nil.')
      end

      @config.logger.log(Logger::INFO, "User '#{user_id}' is in no variation.")
      nil
    end

    def find_bucket(user_id, parent_id, traffic_allocations)
      # Helper function to find the matching entity ID for a given bucketing value in a list of traffic allocations.
      #
      # user_id - String ID for user
      # parent_id - String entity ID to use for bucketing ID
      # traffic_allocations - Array of traffic allocations
      #
      # Returns entity ID corresponding to the provided bucket value or nil if no match is found.

      bucketing_id = sprintf(BUCKETING_ID_TEMPLATE, user_id: user_id, entity_id: parent_id)
      bucket_value = generate_bucket_value(bucketing_id)
      @config.logger.log(Logger::DEBUG, "Assigned bucket #{bucket_value} to user '#{user_id}'.")

      traffic_allocations.each do |traffic_allocation|
        current_end_of_range = traffic_allocation['endOfRange']
        if bucket_value < current_end_of_range
          entity_id = traffic_allocation['entityId']
          return entity_id
        end
      end

      nil
    end

    private

    def generate_bucket_value(bucketing_id)
      # Helper function to generate bucket value in half-closed interval [0, MAX_TRAFFIC_VALUE).
      #
      # bucketing_id - String ID for bucketing.
      #
      # Returns bucket value corresponding to the provided bucketing ID.

      ratio = (generate_unsigned_hash_code_32_bit(bucketing_id)).to_f / MAX_HASH_VALUE
      (ratio * MAX_TRAFFIC_VALUE).to_i
    end

    def generate_unsigned_hash_code_32_bit(bucketing_id)
      # Helper function to retreive hash code
      #
      # bucketing_id - String ID for bucketing.
      #
      # Returns hash code which is a 32 bit unsigned integer.

      MurmurHash3::V32.str_hash(bucketing_id, @bucket_seed) & UNSIGNED_MAX_32_BIT_VALUE
    end
  end
end
