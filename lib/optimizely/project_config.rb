# frozen_string_literal: true

#    Copyright 2016-2019, Optimizely and contributors
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
require_relative 'helpers/constants'
require_relative 'helpers/validator'

module Optimizely
  class ProjectConfig
    # Representation of the Optimizely project config.
    RUNNING_EXPERIMENT_STATUS = ['Running'].freeze
    RESERVED_ATTRIBUTE_PREFIX = '$opt_'

    # Gets project config attributes.
    attr_reader :error_handler
    attr_reader :logger

    attr_reader :account_id
    attr_reader :attributes
    attr_reader :audiences
    attr_reader :typed_audiences
    attr_reader :events
    attr_reader :experiments
    attr_reader :feature_flags
    attr_reader :groups
    attr_reader :project_id
    # Boolean - denotes if Optimizely should remove the last block of visitors' IP address before storing event data
    attr_reader :anonymize_ip
    attr_reader :bot_filtering
    attr_reader :revision
    attr_reader :rollouts
    attr_reader :version

    attr_reader :attribute_key_map
    attr_reader :audience_id_map
    attr_reader :event_key_map
    attr_reader :experiment_feature_map
    attr_reader :experiment_id_map
    attr_reader :experiment_key_map
    attr_reader :feature_flag_key_map
    attr_reader :feature_variable_key_map
    attr_reader :group_key_map
    attr_reader :rollout_id_map
    attr_reader :rollout_experiment_key_map
    attr_reader :variation_id_map
    attr_reader :variation_id_to_variable_usage_map
    attr_reader :variation_key_map

    # Hash of user IDs to a Hash
    # of experiments to variations. This contains all the forced variations
    # set by the user by calling setForcedVariation (it is not the same as the
    # whitelisting forcedVariations data structure in the Experiments class).
    attr_reader :forced_variation_map

    def initialize(datafile, logger, error_handler)
      # ProjectConfig init method to fetch and set project config data
      #
      # datafile - JSON string representing the project

      config = JSON.parse(datafile)

      @error_handler = error_handler
      @logger = logger
      @version = config['version']

      raise InvalidDatafileVersionError, @version unless Helpers::Constants::SUPPORTED_VERSIONS.value?(@version)

      @account_id = config['accountId']
      @attributes = config.fetch('attributes', [])
      @audiences = config.fetch('audiences', [])
      @typed_audiences = config.fetch('typedAudiences', [])
      @events = config.fetch('events', [])
      @experiments = config['experiments']
      @feature_flags = config.fetch('featureFlags', [])
      @groups = config.fetch('groups', [])
      @project_id = config['projectId']
      @anonymize_ip = config.key?('anonymizeIP') ? config['anonymizeIP'] : false
      @bot_filtering = config['botFiltering']
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
      @audience_id_map = @audience_id_map.merge(generate_key_map(@typed_audiences, 'id')) unless @typed_audiences.empty?
      @variation_id_map = {}
      @variation_key_map = {}
      @forced_variation_map = {}
      @variation_id_to_variable_usage_map = {}
      @variation_id_to_experiment_map = {}
      @experiment_key_map.each_value do |exp|
        # Excludes experiments from rollouts
        variations = exp.fetch('variations')
        variations.each do |variation|
          variation_id = variation['id']
          @variation_id_to_experiment_map[variation_id] = exp
        end
      end
      @rollout_id_map = generate_key_map(@rollouts, 'id')
      # split out the experiment key map for rollouts
      @rollout_experiment_key_map = {}
      @rollout_id_map.each_value do |rollout|
        exps = rollout.fetch('experiments')
        @rollout_experiment_key_map = @rollout_experiment_key_map.merge(generate_key_map(exps, 'key'))
      end
      @all_experiments = @experiment_key_map.merge(@rollout_experiment_key_map)
      @all_experiments.each do |key, exp|
        variations = exp.fetch('variations')
        variations.each do |variation|
          variation_id = variation['id']
          variation['featureEnabled'] = variation['featureEnabled'] == true
          variation_variables = variation['variables']
          next if variation_variables.nil?

          @variation_id_to_variable_usage_map[variation_id] = generate_key_map(variation_variables, 'id')
        end
        @variation_id_map[key] = generate_key_map(variations, 'id')
        @variation_key_map[key] = generate_key_map(variations, 'key')
      end
      @feature_flag_key_map = generate_key_map(@feature_flags, 'key')
      @experiment_feature_map = {}
      @feature_variable_key_map = {}
      @feature_flag_key_map.each do |key, feature_flag|
        @feature_variable_key_map[key] = generate_key_map(feature_flag['variables'], 'key')
        feature_flag['experimentIds'].each do |experiment_id|
          @experiment_feature_map[experiment_id] = [feature_flag['id']]
        end
      end
    end

    def experiment_running?(experiment)
      # Determine if experiment corresponding to given key is running
      #
      # experiment - Experiment
      #
      # Returns true if experiment is running
      RUNNING_EXPERIMENT_STATUS.include?(experiment['status'])
    end

    def get_experiment_from_key(experiment_key)
      # Retrieves experiment ID for a given key
      #
      # experiment_key - String key representing the experiment
      #
      # Returns Experiment or nil if not found

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

    def get_event_from_key(event_key)
      # Get event for the provided event key.
      #
      # event_key - Event key for which event is to be determined.
      #
      # Returns Event corresponding to the provided event key.

      event = @event_key_map[event_key]
      return event if event

      @logger.log Logger::ERROR, "Event '#{event_key}' is not in datafile."
      @error_handler.handle_error InvalidEventError
      nil
    end

    def get_audience_from_id(audience_id)
      # Get audience for the provided audience ID
      #
      # audience_id - ID of the audience
      #
      # Returns the audience

      audience = @audience_id_map[audience_id]
      return audience if audience

      @logger.log Logger::ERROR, "Audience '#{audience_id}' is not in datafile."
      @error_handler.handle_error InvalidAudienceError
      nil
    end

    def get_variation_from_id(experiment_key, variation_id)
      # Get variation given experiment key and variation ID
      #
      # experiment_key - Key representing parent experiment of variation
      # variation_id - ID of the variation
      #
      # Returns the variation or nil if not found

      variation_id_map = @variation_id_map[experiment_key]
      if variation_id_map
        variation = variation_id_map[variation_id]
        return variation if variation

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

    def get_whitelisted_variations(experiment_key)
      # Retrieves whitelisted variations for a given experiment Key
      #
      # experiment_key - String Key representing the experiment
      #
      # Returns whitelisted variations for the experiment or nil

      experiment = @experiment_key_map[experiment_key]
      return experiment['forcedVariations'] if experiment

      @logger.log Logger::ERROR, "Experiment key '#{experiment_key}' is not in datafile."
      @error_handler.handle_error InvalidExperimentError
    end

    def get_forced_variation(experiment_key, user_id)
      # Gets the forced variation for the given user and experiment.
      #
      # experiment_key - String Key for experiment.
      # user_id - String ID for user
      #
      # Returns Variation The variation which the given user and experiment should be forced into.

      return nil unless Optimizely::Helpers::Validator.inputs_valid?(
        {
          experiment_key: experiment_key,
          user_id: user_id
        }, @logger, Logger::DEBUG
      )

      unless @forced_variation_map.key? user_id
        @logger.log(Logger::DEBUG, "User '#{user_id}' is not in the forced variation map.")
        return nil
      end

      experiment_to_variation_map = @forced_variation_map[user_id]
      experiment = get_experiment_from_key(experiment_key)
      experiment_id = experiment['id'] if experiment
      # check for nil and empty string experiment ID
      # this case is logged in get_experiment_from_key
      return nil if experiment_id.nil? || experiment_id.empty?

      unless experiment_to_variation_map.key? experiment_id
        @logger.log(Logger::DEBUG, "No experiment '#{experiment_key}' mapped to user '#{user_id}' "\
                    'in the forced variation map.')
        return nil
      end

      variation_id = experiment_to_variation_map[experiment_id]
      variation_key = ''
      variation = get_variation_from_id(experiment_key, variation_id)
      variation_key = variation['key'] if variation

      # check if the variation exists in the datafile
      # this case is logged in get_variation_from_id
      return nil if variation_key.empty?

      @logger.log(Logger::DEBUG, "Variation '#{variation_key}' is mapped to experiment '#{experiment_key}' "\
                  "and user '#{user_id}' in the forced variation map")

      variation
    end

    def set_forced_variation(experiment_key, user_id, variation_key)
      # Sets a Hash of user IDs to a Hash of experiments to forced variations.
      #
      # experiment_key - String Key for experiment.
      # user_id - String ID for user.
      # variation_key - String Key for variation. If null, then clear the existing experiment-to-variation mapping.
      #
      # Returns a boolean value that indicates if the set completed successfully.

      input_values = {experiment_key: experiment_key, user_id: user_id}
      input_values[:variation_key] = variation_key unless variation_key.nil?
      return false unless Optimizely::Helpers::Validator.inputs_valid?(input_values, @logger, Logger::DEBUG)

      experiment = get_experiment_from_key(experiment_key)
      experiment_id = experiment['id'] if experiment
      #  check if the experiment exists in the datafile
      return false if experiment_id.nil? || experiment_id.empty?

      #  clear the forced variation if the variation key is null
      if variation_key.nil?
        @forced_variation_map[user_id].delete(experiment_id) if @forced_variation_map.key? user_id
        @logger.log(Logger::DEBUG, "Variation mapped to experiment '#{experiment_key}' has been removed for user "\
                    "'#{user_id}'.")
        return true
      end

      variation_id = get_variation_id_from_key(experiment_key, variation_key)

      #  check if the variation exists in the datafile
      unless variation_id
        #  this case is logged in get_variation_id_from_key
        return false
      end

      @forced_variation_map[user_id] = {} unless @forced_variation_map.key? user_id
      @forced_variation_map[user_id][experiment_id] = variation_id
      @logger.log(Logger::DEBUG, "Set variation '#{variation_id}' for experiment '#{experiment_id}' and "\
                  "user '#{user_id}' in the forced variation map.")
      true
    end

    def get_attribute_id(attribute_key)
      # Get attribute ID for the provided attribute key.
      #
      # Args:
      #   Attribute key for which attribute is to be fetched.
      #
      # Returns:
      #   Attribute ID corresponding to the provided attribute key.
      attribute = @attribute_key_map[attribute_key]
      has_reserved_prefix = attribute_key.to_s.start_with?(RESERVED_ATTRIBUTE_PREFIX)
      unless attribute.nil?
        if has_reserved_prefix
          @logger.log(Logger::WARN, "Attribute '#{attribute_key}' unexpectedly has reserved prefix '#{RESERVED_ATTRIBUTE_PREFIX}'; "\
                      'using attribute ID instead of reserved attribute name.')
        end
        return attribute['id']
      end
      return attribute_key if has_reserved_prefix

      @logger.log Logger::ERROR, "Attribute key '#{attribute_key}' is not in datafile."
      @error_handler.handle_error InvalidAttributeError
      nil
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
      end

      false
    end

    def get_feature_flag_from_key(feature_flag_key)
      # Retrieves the feature flag with the given key
      #
      # feature_flag_key - String feature key
      #
      # Returns feature flag if found, otherwise nil
      feature_flag = @feature_flag_key_map[feature_flag_key]
      return feature_flag if feature_flag

      @logger.log Logger::ERROR, "Feature flag key '#{feature_flag_key}' is not in datafile."
      nil
    end

    def get_feature_variable(feature_flag, variable_key)
      # Retrieves the variable with the given key for the given feature
      #
      # feature_flag - The feature flag for which we are retrieving the variable
      # variable_key - String variable key
      #
      # Returns variable if found, otherwise nil
      feature_flag_key = feature_flag['key']
      variable = @feature_variable_key_map[feature_flag_key][variable_key]
      return variable if variable

      @logger.log Logger::ERROR, "No feature variable was found for key '#{variable_key}' in feature flag "\
                  "'#{feature_flag_key}'."
      nil
    end

    def get_rollout_from_id(rollout_id)
      # Retrieves the rollout with the given ID
      #
      # rollout_id - String rollout ID
      #
      # Returns the rollout if found, otherwise nil
      rollout = @rollout_id_map[rollout_id]
      return rollout if rollout

      @logger.log Logger::ERROR, "Rollout with ID '#{rollout_id}' is not in the datafile."
      nil
    end

    def feature_experiment?(experiment_id)
      # Determines if given experiment is a feature test.
      #
      # experiment_id - String experiment ID
      #
      # Returns true if experiment belongs to  any feature,
      #              false otherwise.
      @experiment_feature_map.key?(experiment_id)
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
