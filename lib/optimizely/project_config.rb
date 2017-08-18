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
require 'json'

module Optimizely

  V1_CONFIG_VERSION = '1'

  UNSUPPORTED_VERSIONS = [V1_CONFIG_VERSION]

  class ProjectConfig
    # Representation of the Optimizely project config.
    RUNNING_EXPERIMENT_STATUS = ['Running']

    # Gets project config attributes.
    attr_reader :error_handler
    attr_reader :logger

    attr_reader :account_id
    attr_reader :attributes
    attr_reader :audiences
    attr_reader :events
    attr_reader :experiments
    attr_reader :groups
    attr_reader :parsing_succeeded
    attr_reader :project_id
    attr_reader :revision
    attr_reader :rollouts
    attr_reader :version

    attr_reader :attribute_key_map
    attr_reader :audience_id_map
    attr_reader :event_key_map
    attr_reader :experiment_id_map
    attr_reader :experiment_key_map
    attr_reader :feature_flag_key_map
    attr_reader :group_key_map
    attr_reader :rollout_id_map
    attr_reader :rollout_experiment_id_map
    attr_reader :variation_id_map
    attr_reader :variation_id_to_variable_usage_map
    attr_reader :variation_key_map

    def initialize(datafile, logger, error_handler)
      # ProjectConfig init method to fetch and set project config data
      #
      # datafile - JSON string representing the project

      config = JSON.load(datafile)

      @parsing_succeeded = false
      @error_handler = error_handler
      @logger = logger
      @version = config['version']

      if UNSUPPORTED_VERSIONS.include?(@version)
        return
      end

      @account_id = config['accountId']
      @attributes = config.fetch('attributes', [])
      @audiences = config.fetch('audiences', [])
      @events = config.fetch('events', [])
      @experiments = config['experiments']
      @feature_flags = config.fetch('featureFlags', [])
      @groups = config.fetch('groups', [])
      @project_id = config['projectId']
      @revision = config['revision']
      @rollouts = config.fetch('rollouts', [])

      # Utility maps for quick lookup
      @attribute_key_map = generate_key_map(@attributes, 'key')
      @event_key_map = generate_key_map(@events, 'key')
      @group_key_map = generate_key_map(@groups, 'id')
      @group_key_map.each do |key, group|
        exps = group.fetch('experiments')
        exps.each do |exp|
          @experiments.push(exp.merge('groupId' => key))
        end
      end
      @experiment_key_map = generate_key_map(@experiments, 'key')
      @experiment_id_map = generate_key_map(@experiments, 'id')
      @audience_id_map = generate_key_map(@audiences, 'id')
      @variation_id_map = {}
      @variation_key_map = {}
      @variation_id_to_variable_usage_map = {}
      @rollout_id_map = generate_key_map(@rollouts, 'id')
      # split out the experiment id map for rollouts
      @rollout_experiment_id_map = {}
      @rollout_id_map.each do |id, rollout|
        exps = rollout.fetch('experiments')
        @rollout_experiment_id_map = @rollout_experiment_id_map.merge(generate_key_map(exps, 'id'))
      end
      @all_experiments = @experiment_key_map.merge(@rollout_experiment_id_map)
      @all_experiments.each do |key, exp|
        variations = exp.fetch('variations')
        @variation_id_map[key] = generate_key_map(variations, 'id')
        @variation_key_map[key] = generate_key_map(variations, 'key')

        variations.each do |variation|
          variation_id = variation['id']
          variation_variables = variation['variables']
          unless variation_variables.nil?
            @variation_id_to_variable_usage_map[variation_id] = generate_key_map(variation_variables, 'id')
          end
        end
      end
      @feature_flag_key_map = generate_key_map(@feature_flags, 'key')
      @parsing_succeeded = true
    end

    def experiment_running?(experiment)
      # Determine if experiment corresponding to given key is running
      #
      # experiment - Experiment
      #
      # Returns true if experiment is running
      return RUNNING_EXPERIMENT_STATUS.include?(experiment['status'])
    end

    def get_experiment_from_key(experiment_key)
      # Retrieves experiment ID for a given key
      #
      # experiment_key - String key representing the experiment
      #
      # Returns Experiment

      experiment = @experiment_key_map[experiment_key]
      return experiment if experiment
      @logger.log Logger::ERROR, "Experiment key '#{experiment_key}' is not in datafile."
      @error_handler.handle_error InvalidExperimentError
      nil
    end

    def get_experiment_key(experiment_id)
      # Retrieves experiment key for a given ID.
      #
      # experiment_id - String ID representing the experiment.
      #
      # Returns String key.

      experiment = @experiment_id_map[experiment_id]
      return experiment['key'] unless experiment.nil?
      @logger.log Logger::ERROR, "Experiment id '#{experiment_id}' is not in datafile."
      @error_handler.handle_error InvalidExperimentError
      nil
    end

    def get_experiment_ids_for_event(event_key)
      # Get experiment IDs for the provided event key.
      #
      # event_key - Event key for which experiment IDs are to be retrieved.
      #
      # Returns array of all experiment IDs for the event.

      event = @event_key_map[event_key]
      return event['experimentIds'] if event
      @logger.log Logger::ERROR, "Event '#{event_key}' is not in datafile."
      @error_handler.handle_error InvalidEventError
      []
    end

    def get_audience_conditions_from_id(audience_id)
      # Get audience conditions for the provided audience ID
      #
      # audience_id - ID of the audience
      #
      # Returns conditions for the audience

      audience = @audience_id_map[audience_id]
      return audience['conditions'] if audience
      @logger.log Logger::ERROR, "Audience '#{audience_id}' is not in datafile."
      @error_handler.handle_error InvalidAudienceError
      nil
    end

    def get_variation_key_from_id(experiment_key, variation_id)
      # Get variation key given experiment key and variation ID
      #
      # experiment_key - Key representing parent experiment of variation
      # variation_id - ID of the variation
      #
      # Returns key of the variation

      variation_id_map = @variation_id_map[experiment_key]
      if variation_id_map
        variation = variation_id_map[variation_id]
        return variation['key'] if variation
        @logger.log Logger::ERROR, "Variation id '#{variation_id}' is not in datafile."
        @error_handler.handle_error InvalidVariationError
        return nil
      end

      @logger.log Logger::ERROR, "Experiment key '#{experiment_key}' is not in datafile."
      @error_handler.handle_error InvalidExperimentError
      nil
    end

    def get_variation_id_from_key(experiment_key, variation_key)
      # Get variation ID given experiment key and variation key
      #
      # experiment_key - Key representing parent experiment of variation
      # variation_key - Key of the variation
      #
      # Returns ID of the variation

      variation_key_map = @variation_key_map[experiment_key]
      if variation_key_map
        variation = variation_key_map[variation_key]
        return variation['id'] if variation
        @logger.log Logger::ERROR, "Variation key '#{variation_key}' is not in datafile."
        @error_handler.handle_error InvalidVariationError
        return nil
      end

      @logger.log Logger::ERROR, "Experiment key '#{experiment_key}' is not in datafile."
      @error_handler.handle_error InvalidExperimentError
      nil
    end

    def get_forced_variations(experiment_key)
      # Retrieves forced variations for a given experiment Key
      #
      # experiment_key - String Key representing the experiment
      #
      # Returns forced variations for the experiment or nil

      experiment = @experiment_key_map[experiment_key]
      return experiment['forcedVariations'] if experiment
      @logger.log Logger::ERROR, "Experiment key '#{experiment_key}' is not in datafile."
      @error_handler.handle_error InvalidExperimentError
    end

    def get_attribute_id(attribute_key)
      attribute = @attribute_key_map[attribute_key]
      return attribute['id'] if attribute
      @logger.log Logger::ERROR, "Attribute key '#{attribute_key}' is not in datafile."
      @error_handler.handle_error InvalidAttributeError
      nil
    end

    def parsing_succeeded?
      # Helper method to determine if parsing the datafile was successful.
      #
      # Returns Boolean depending on whether parsing the datafile succeeded or not.

      @parsing_succeeded
    end

    def variation_id_exists?(experiment_id, variation_id)
      # Determines if a given experiment ID / variation ID pair exists in the datafile
      #
      # experiment_id - String experiment ID
      # variation_id - String variation ID
      #
      # Returns true if variation is in datafile

      experiment_key = get_experiment_key(experiment_id)
      variation_id_map = @variation_id_map[experiment_key]
      if variation_id_map
        variation = variation_id_map[variation_id]
        return true if variation
        @logger.log Logger::ERROR, "Variation ID '#{variation_id}' is not in datafile."
        @error_handler.handle_error InvalidVariationError
        return false
      end

      false
    end

    private

    def generate_key_map(array, key)
      # Helper method to generate map from key to hash in array of hashes
      #
      # array - Array consisting of hash
      # key - Key in each hash which will be key in the map
      #
      # Returns map mapping key to hash

      Hash[array.map { |obj| [obj[key], obj] }]
    end
  end
end
