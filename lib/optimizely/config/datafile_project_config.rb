# frozen_string_literal: true

#    Copyright 2019-2022, Optimizely and contributors
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
require 'optimizely/project_config'
require 'optimizely/helpers/constants'
require 'optimizely/helpers/validator'
module Optimizely
  class DatafileProjectConfig < ProjectConfig
    # Representation of the Optimizely project config.
    RUNNING_EXPERIMENT_STATUS = ['Running'].freeze
    RESERVED_ATTRIBUTE_PREFIX = '$opt_'

    attr_reader :datafile, :account_id, :attributes, :audiences, :typed_audiences, :events,
                :experiments, :feature_flags, :groups, :project_id, :bot_filtering, :revision,
                :sdk_key, :environment_key, :rollouts, :version, :send_flag_decisions,
                :attribute_key_map, :attribute_id_to_key_map, :audience_id_map, :event_key_map, :experiment_feature_map,
                :experiment_id_map, :experiment_key_map, :feature_flag_key_map, :feature_variable_key_map,
                :group_id_map, :rollout_id_map, :rollout_experiment_id_map, :variation_id_map,
                :variation_id_to_variable_usage_map, :variation_key_map, :variation_id_map_by_experiment_id,
                :variation_key_map_by_experiment_id, :flag_variation_map, :integration_key_map, :integrations,
                :public_key_for_odp, :host_for_odp, :all_segments, :region
    # Boolean - denotes if Optimizely should remove the last block of visitors' IP address before storing event data
    attr_reader :anonymize_ip

    def initialize(datafile, logger, error_handler)
      # ProjectConfig init method to fetch and set project config data
      #
      # datafile - JSON string representing the project
      super()

      config = JSON.parse(datafile)

      @datafile = datafile
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
      @sdk_key = config.fetch('sdkKey', '')
      @environment_key = config.fetch('environmentKey', '')
      @rollouts = config.fetch('rollouts', [])
      @send_flag_decisions = config.fetch('sendFlagDecisions', false)
      @integrations = config.fetch('integrations', [])
      @region = config.fetch('region', 'US')

      # Json type is represented in datafile as a subtype of string for the sake of backwards compatibility.
      # Converting it to a first-class json type while creating Project Config
      @feature_flags.each do |feature_flag|
        feature_flag['variables'].each do |variable|
          if variable['type'] == 'string' && variable['subType'] == 'json'
            variable['type'] = 'json'
            variable.delete('subType')
          end
        end
      end

      # Utility maps for quick lookup
      @attribute_key_map = generate_key_map(@attributes, 'key')
      @attribute_id_to_key_map = {}
      @attributes.each do |attribute|
        @attribute_id_to_key_map[attribute['id']] = attribute['key']
      end
      @event_key_map = generate_key_map(@events, 'key')
      @group_id_map = generate_key_map(@groups, 'id')
      @group_id_map.each do |key, group|
        exps = group.fetch('experiments')
        exps.each do |exp|
          @experiments.push(exp.merge('groupId' => key))
        end
      end
      @experiment_key_map = generate_key_map(@experiments, 'key')
      @experiment_id_map = generate_key_map(@experiments, 'id')
      @audience_id_map = generate_key_map(@audiences, 'id')
      @integration_key_map = generate_key_map(@integrations, 'key', first_value: true)
      @audience_id_map = @audience_id_map.merge(generate_key_map(@typed_audiences, 'id')) unless @typed_audiences.empty?
      @variation_id_map = {}
      @variation_key_map = {}
      @variation_id_map_by_experiment_id = {}
      @variation_key_map_by_experiment_id = {}
      @variation_id_to_variable_usage_map = {}
      @variation_id_to_experiment_map = {}
      @flag_variation_map = {}

      @experiment_id_map.each_value do |exp|
        # Excludes experiments from rollouts
        variations = exp.fetch('variations')
        variations.each do |variation|
          variation_id = variation['id']
          @variation_id_to_experiment_map[variation_id] = exp
        end
      end
      @rollout_id_map = generate_key_map(@rollouts, 'id')
      # split out the experiment key map for rollouts
      @rollout_experiment_id_map = {}
      @rollout_id_map.each_value do |rollout|
        exps = rollout.fetch('experiments')
        @rollout_experiment_id_map = @rollout_experiment_id_map.merge(generate_key_map(exps, 'id'))
      end

      if (odp_integration = @integration_key_map&.fetch('odp', nil))
        @public_key_for_odp = odp_integration['publicKey']
        @host_for_odp = odp_integration['host']
      end

      @all_segments = []
      @audience_id_map.each_value do |audience|
        @all_segments.concat Audience.get_segments(audience['conditions'])
      end

      @flag_variation_map = generate_feature_variation_map(@feature_flags)
      @all_experiments = @experiment_id_map.merge(@rollout_experiment_id_map)
      @all_experiments.each do |id, exp|
        variations = exp.fetch('variations')
        variations.each do |variation|
          variation_id = variation['id']
          variation['featureEnabled'] = variation['featureEnabled'] == true
          variation_variables = variation['variables']
          next if variation_variables.nil?

          @variation_id_to_variable_usage_map[variation_id] = generate_key_map(variation_variables, 'id')
        end
        @variation_id_map[exp['key']] = generate_key_map(variations, 'id')
        @variation_key_map[exp['key']] = generate_key_map(variations, 'key')
        @variation_id_map_by_experiment_id[id] = generate_key_map(variations, 'id')
        @variation_key_map_by_experiment_id[id] = generate_key_map(variations, 'key')
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

    def get_rules_for_flag(feature_flag)
      # Retrieves rules for a given feature flag
      #
      # feature_flag - String key representing the feature_flag
      #
      # Returns rules in feature flag
      rules = feature_flag['experimentIds'].map { |exp_id| @experiment_id_map[exp_id] }
      rollout = feature_flag['rolloutId'].empty? ? nil : @rollout_id_map[feature_flag['rolloutId']]

      if rollout
        rollout_experiments = rollout.fetch('experiments')
        rollout_experiments.each do |exp|
          rules.push(exp)
        end
      end
      rules
    end

    def self.create(datafile, logger, error_handler, skip_json_validation)
      # Looks up and sets datafile and config based on response body.
      #
      # datafile - JSON string representing the Optimizely project.
      # logger - Provides a logger instance.
      # error_handler - Provides a handle_error method to handle exceptions.
      # skip_json_validation - Optional boolean param which allows skipping JSON schema
      #                       validation upon object invocation. By default JSON schema validation will be performed.
      # Returns instance of DatafileProjectConfig, nil otherwise.
      logger ||= SimpleLogger.new
      if !skip_json_validation && !Helpers::Validator.datafile_valid?(datafile)
        logger.log(Logger::ERROR, InvalidInputError.new('datafile').message)
        return nil
      end

      begin
        config = new(datafile, logger, error_handler)
      rescue StandardError => e
        error_to_handle = e.instance_of?(InvalidDatafileVersionError) ? e : InvalidInputError.new('datafile')
        error_msg = error_to_handle.message

        logger.log(Logger::ERROR, error_msg)
        error_handler.handle_error error_to_handle
        return nil
      end

      config
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

      invalid_experiment_error = InvalidExperimentError.new(experiment_key: experiment_key)
      @logger.log Logger::ERROR, invalid_experiment_error.message
      @error_handler.handle_error invalid_experiment_error
      nil
    end

    def get_experiment_from_id(experiment_id)
      # Retrieves experiment ID for a given key
      #
      # experiment_id - String id representing the experiment
      #
      # Returns Experiment or nil if not found

      experiment = @experiment_id_map[experiment_id]
      return experiment if experiment

      invalid_experiment_error = InvalidExperimentError.new(experiment_id: experiment_id)
      @logger.log Logger::ERROR, invalid_experiment_error.message
      @error_handler.handle_error invalid_experiment_error
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

      invalid_experiment_error = InvalidExperimentError.new(experiment_id: experiment_id)
      @logger.log Logger::ERROR, invalid_experiment_error.message
      @error_handler.handle_error invalid_experiment_error
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

      invalid_event_error = InvalidEventError.new(event_key)
      @logger.log Logger::ERROR, invalid_event_error.message
      @error_handler.handle_error invalid_event_error
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

      invalid_audience_error = InvalidAudienceError.new(audience_id)
      @logger.log Logger::ERROR, invalid_audience_error.message
      @error_handler.handle_error invalid_audience_error
      nil
    end

    def get_variation_from_flag(flag_key, target_value, attribute)
      variations = @flag_variation_map[flag_key]
      return variations.select { |variation| variation[attribute] == target_value }.first if variations

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

        invalid_variation_error = InvalidVariationError.new(variation_id: variation_id)
        @logger.log Logger::ERROR, invalid_variation_error.message
        @error_handler.handle_error invalid_variation_error
        return nil
      end

      invalid_experiment_error = InvalidExperimentError.new(experiment_key: experiment_key)
      @logger.log Logger::ERROR, invalid_experiment_error.message
      @error_handler.handle_error invalid_experiment_error
      nil
    end

    def get_variation_from_id_by_experiment_id(experiment_id, variation_id)
      # Get variation given experiment ID and variation ID
      #
      # experiment_id - ID representing parent experiment of variation
      # variation_id - ID of the variation
      #
      # Returns the variation or nil if not found

      variation_id_map_by_experiment_id = @variation_id_map_by_experiment_id[experiment_id]
      if variation_id_map_by_experiment_id
        variation = variation_id_map_by_experiment_id[variation_id]
        return variation if variation

        invalid_variation_error = InvalidVariationError.new(variation_id: variation_id)
        @logger.log Logger::ERROR, invalid_variation_error.message
        @error_handler.handle_error invalid_variation_error
        return nil
      end

      invalid_experiment_error = InvalidExperimentError.new(experiment_id: experiment_id)
      @logger.log Logger::ERROR, invalid_experiment_error.message
      @error_handler.handle_error invalid_experiment_error
      nil
    end

    def get_variation_id_from_key_by_experiment_id(experiment_id, variation_key)
      # Get variation given experiment ID and variation key
      #
      # experiment_id - ID representing parent experiment of variation
      # variation_key - Key of the variation
      #
      # Returns the variation or nil if not found

      variation_key_map = @variation_key_map_by_experiment_id[experiment_id]
      if variation_key_map
        variation = variation_key_map[variation_key]
        return variation['id'] if variation

        invalid_variation_error = InvalidVariationError.new(variation_key: variation_key)
        @logger.log Logger::ERROR, invalid_variation_error.message
        @error_handler.handle_error invalid_variation_error
        return nil
      end

      invalid_experiment_error = InvalidExperimentError.new(experiment_id: experiment_id)
      @logger.log Logger::ERROR, invalid_experiment_error.message
      @error_handler.handle_error invalid_experiment_error
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

        invalid_variation_error = InvalidVariationError.new(variation_key: variation_key)
        @logger.log Logger::ERROR, invalid_variation_error.message
        @error_handler.handle_error invalid_variation_error
        return nil
      end

      invalid_experiment_error = InvalidExperimentError.new(experiment_key: experiment_key)
      @logger.log Logger::ERROR, invalid_experiment_error.message
      @error_handler.handle_error invalid_experiment_error
      nil
    end

    def get_whitelisted_variations(experiment_id)
      # Retrieves whitelisted variations for a given experiment id
      #
      # experiment_id - String id representing the experiment
      #
      # Returns whitelisted variations for the experiment or nil

      experiment = @experiment_id_map[experiment_id]
      return experiment['forcedVariations'] if experiment

      invalid_experiment_error = InvalidExperimentError.new(experiment_id: experiment_id)
      @logger.log Logger::ERROR, invalid_experiment_error.message
      @error_handler.handle_error invalid_experiment_error
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

      invalid_attribute_error = InvalidAttributeError.new(attribute_key)
      @logger.log Logger::ERROR, invalid_attribute_error.message
      @error_handler.handle_error invalid_attribute_error
      nil
    end

    def get_attribute_by_key(attribute_key)
      # Get attribute for the provided attribute key.
      #
      # Args:
      #   Attribute key for which attribute is to be fetched.
      #
      # Returns:
      #   Attribute corresponding to the provided attribute key.
      attribute = @attribute_key_map[attribute_key]
      return attribute if attribute

      invalid_attribute_error = InvalidAttributeError.new(attribute_key)
      @logger.log Logger::ERROR, invalid_attribute_error.message
      @error_handler.handle_error invalid_attribute_error
      nil
    end

    def get_attribute_key_by_id(attribute_id)
      # Get attribute key for the provided attribute ID.
      #
      # Args:
      #   Attribute ID for which attribute is to be fetched.
      #
      # Returns:
      #   Attribute key corresponding to the provided attribute ID.
      attribute = @attribute_id_to_key_map[attribute_id]
      return attribute if attribute

      invalid_attribute_error = InvalidAttributeError.new(attribute_id)
      @logger.log Logger::ERROR, invalid_attribute_error.message
      @error_handler.handle_error invalid_attribute_error
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

        invalid_variation_error = InvalidVariationError.new(variation_id: variation_id)
        @logger.log Logger::ERROR, invalid_variation_error.message
        @error_handler.handle_error invalid_variation_error
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

    def rollout_experiment?(experiment_id)
      # Determines if given experiment is a rollout test.
      #
      # experiment_id - String experiment ID
      #
      # Returns true if experiment belongs to  any rollout,
      #              false otherwise.
      @rollout_experiment_id_map.key?(experiment_id)
    end

    private

    def generate_feature_variation_map(feature_flags)
      flag_variation_map = {}
      feature_flags.each do |flag|
        variations = []
        get_rules_for_flag(flag).each do |rule|
          rule['variations'].each do |rule_variation|
            variations.push(rule_variation) if variations.select { |variation| variation['id'] == rule_variation['id'] }.empty?
          end
        end
        flag_variation_map[flag['key']] = variations
      end
      flag_variation_map
    end

    def generate_key_map(array, key, first_value: false)
      # Helper method to generate map from key to hash in array of hashes
      #
      # array - Array consisting of hash
      # key - Key in each hash which will be key in the map
      # first_value - Determines which value to save if there are duplicate keys. By default the last instance of the key
      #               will be saved. Set to true to save the first key/value encountered.
      #
      # Returns map mapping key to hash

      array
        .group_by { |obj| obj[key] }
        .transform_values { |group| first_value ? group.first : group.last }
    end
  end
end
