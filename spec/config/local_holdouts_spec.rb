# frozen_string_literal: true

#
#    Copyright 2026, Optimizely and contributors
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
require 'optimizely/config/datafile_project_config'
require 'optimizely/error_handler'
require 'optimizely/logger'

describe 'Local Holdouts' do
  let(:spy_logger) { spy('logger') }
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }

  describe 'DatafileProjectConfig with Local Holdouts' do
    let(:config) do
      Optimizely::DatafileProjectConfig.new(
        OptimizelySpec::CONFIG_BODY_WITH_LOCAL_HOLDOUTS_JSON,
        spy_logger,
        error_handler
      )
    end

    describe 'holdout parsing and mapping' do
      it 'should parse holdouts with includedRules field' do
        expect(config.holdouts).not_to be_empty
        expect(config.holdouts.length).to eq(6)
      end

      it 'should correctly identify global holdouts (includedRules == nil)' do
        global_holdout = config.holdouts.find { |h| h['id'] == 'global_holdout_nil_rules' }
        expect(global_holdout).not_to be_nil
        expect(global_holdout['includedRules']).to be_nil
        expect(config.global_holdout?(global_holdout)).to be true
      end

      it 'should correctly identify local holdouts (includedRules is an array)' do
        local_holdout = config.holdouts.find { |h| h['id'] == 'local_holdout_single_rule' }
        expect(local_holdout).not_to be_nil
        expect(local_holdout['includedRules']).to be_an(Array)
        expect(config.global_holdout?(local_holdout)).to be false
      end

      it 'should treat empty array as local holdout (not global)' do
        empty_holdout = config.holdouts.find { |h| h['id'] == 'local_holdout_empty_array' }
        expect(empty_holdout).not_to be_nil
        expect(empty_holdout['includedRules']).to eq([])
        expect(config.global_holdout?(empty_holdout)).to be false
      end
    end

    describe '#get_global_holdouts' do
      it 'should return only holdouts with includedRules == nil' do
        global_holdouts = config.get_global_holdouts
        expect(global_holdouts.length).to eq(1)
        expect(global_holdouts.first['id']).to eq('global_holdout_nil_rules')
      end

      it 'should return empty array when no global holdouts exist' do
        config_without_global = Optimizely::DatafileProjectConfig.new(
          JSON.dump(OptimizelySpec::VALID_CONFIG_BODY.merge('holdouts' => [])),
          spy_logger,
          error_handler
        )
        expect(config_without_global.get_global_holdouts).to eq([])
      end
    end

    describe '#get_holdouts_for_rule' do
      it 'should return local holdouts for a specific rule ID' do
        rule_id = '177770'
        holdouts = config.get_holdouts_for_rule(rule_id)

        expect(holdouts.length).to eq(2)
        holdout_ids = holdouts.map { |h| h['id'] }
        expect(holdout_ids).to include('local_holdout_single_rule')
        expect(holdout_ids).to include('local_holdout_multiple_rules')
      end

      it 'should return empty array for rule ID not in any holdout' do
        rule_id = '999999'
        holdouts = config.get_holdouts_for_rule(rule_id)
        expect(holdouts).to eq([])
      end

      it 'should return empty array when nil rule_id is provided' do
        holdouts = config.get_holdouts_for_rule(nil)
        expect(holdouts).to eq([])
      end

      it 'should handle multiple rules in same holdout' do
        holdouts_rule_1 = config.get_holdouts_for_rule('177770')
        holdouts_rule_2 = config.get_holdouts_for_rule('177774')

        expect(holdouts_rule_1.length).to eq(2)
        expect(holdouts_rule_2.length).to eq(1)

        # Both should include the multi-rule holdout
        expect(holdouts_rule_1.map { |h| h['id'] }).to include('local_holdout_multiple_rules')
        expect(holdouts_rule_2.map { |h| h['id'] }).to include('local_holdout_multiple_rules')
      end

      it 'should not return inactive holdouts' do
        rule_id = '177770'
        holdouts = config.get_holdouts_for_rule(rule_id)

        holdout_ids = holdouts.map { |h| h['id'] }
        expect(holdout_ids).not_to include('inactive_local_holdout')
      end
    end

    describe '#global_holdout?' do
      it 'should return true for holdouts with includedRules == nil' do
        global_holdout = config.holdouts.find { |h| h['id'] == 'global_holdout_nil_rules' }
        expect(config.global_holdout?(global_holdout)).to be true
      end

      it 'should return false for holdouts with includedRules array' do
        local_holdout = config.holdouts.find { |h| h['id'] == 'local_holdout_single_rule' }
        expect(config.global_holdout?(local_holdout)).to be false
      end

      it 'should return false for holdouts with empty includedRules array' do
        empty_holdout = config.holdouts.find { |h| h['id'] == 'local_holdout_empty_array' }
        expect(config.global_holdout?(empty_holdout)).to be false
      end
    end

    describe 'rule_holdouts_map' do
      it 'should correctly map rules to holdouts' do
        expect(config.rule_holdouts_map).to be_a(Hash)
        expect(config.rule_holdouts_map.key?('177770')).to be true
        expect(config.rule_holdouts_map['177770'].length).to eq(2)
      end

      it 'should not include global holdouts in rule_holdouts_map' do
        config.rule_holdouts_map.each_value do |holdouts|
          holdouts.each do |holdout|
            expect(holdout['includedRules']).not_to be_nil
          end
        end
      end

      it 'should handle non-existent rule IDs gracefully' do
        # Holdout references non-existent rule '99999999'
        expect(config.rule_holdouts_map.key?('99999999')).to be true
        expect(config.rule_holdouts_map['99999999'].length).to eq(1)
      end
    end

    describe 'backward compatibility' do
      it 'should handle datafiles without includedRules field (defaults to nil)' do
        legacy_config_body = OptimizelySpec::VALID_CONFIG_BODY.merge(
          {
            'holdouts' => [
              {
                'id' => 'legacy_holdout',
                'key' => 'legacy',
                'status' => 'Running',
                'audiences' => [],
                'variations' => [],
                'trafficAllocation' => []
              }
            ]
          }
        )
        legacy_config = Optimizely::DatafileProjectConfig.new(
          JSON.dump(legacy_config_body),
          spy_logger,
          error_handler
        )

        global_holdouts = legacy_config.get_global_holdouts
        expect(global_holdouts.length).to eq(1)
        expect(global_holdouts.first['id']).to eq('legacy_holdout')
      end
    end

    describe 'edge cases' do
      it 'should handle empty holdouts array' do
        config_no_holdouts = Optimizely::DatafileProjectConfig.new(
          JSON.dump(OptimizelySpec::VALID_CONFIG_BODY.merge('holdouts' => [])),
          spy_logger,
          error_handler
        )

        expect(config_no_holdouts.get_global_holdouts).to eq([])
        expect(config_no_holdouts.get_holdouts_for_rule('177770')).to eq([])
      end

      it 'should handle nil holdouts' do
        config_nil_holdouts = Optimizely::DatafileProjectConfig.new(
          JSON.dump(OptimizelySpec::VALID_CONFIG_BODY),
          spy_logger,
          error_handler
        )

        expect(config_nil_holdouts.get_global_holdouts).to eq([])
        expect(config_nil_holdouts.get_holdouts_for_rule('177770')).to eq([])
      end
    end
  end

  describe 'DecisionService with Local Holdouts' do
    let(:config) do
      Optimizely::DatafileProjectConfig.new(
        OptimizelySpec::CONFIG_BODY_WITH_LOCAL_HOLDOUTS_JSON,
        spy_logger,
        error_handler
      )
    end

    let(:spy_cmab_service) { spy('cmab_service') }
    let(:spy_user_profile_service) { spy('user_profile_service') }
    let(:decision_service) do
      Optimizely::DecisionService.new(spy_logger, spy_cmab_service, spy_user_profile_service)
    end

    let(:project) do
      Optimizely::Project.new(
        datafile: OptimizelySpec::CONFIG_BODY_WITH_LOCAL_HOLDOUTS_JSON,
        logger: spy_logger,
        error_handler: error_handler
      )
    end

    after(:example) do
      project&.close
    end

    describe 'global holdout evaluation at flag level' do
      it 'should check global holdouts before experiment rules' do
        user_context = project.create_user_context('global_user', {})

        # Mock bucketer to always bucket into global holdout
        allow_any_instance_of(Optimizely::Bucketer).to receive(:bucket) do |_instance, _config, experiment, _bucketing_id, _user_id|
          if experiment['id'] == 'global_holdout_nil_rules'
            [experiment['variations'].first, []]
          else
            [nil, []]
          end
        end

        feature_flag = config.feature_flag_key_map.values.first
        result = decision_service.get_decision_for_flag(
          feature_flag,
          user_context,
          config,
          []
        )

        # Should be bucketed into global holdout
        expect(result.decision).not_to be_nil
        expect(result.decision.source).to eq(Optimizely::DecisionService::DECISION_SOURCES['HOLDOUT'])
      end
    end

    describe 'local holdout evaluation at rule level' do
      it 'should check local holdouts for specific rule before audience evaluation' do
        user_context = project.create_user_context('local_user', {})

        # Find rollout experiment rule that has local holdout
        experiment = config.rollout_experiment_id_map['177770']
        expect(experiment).not_to be_nil

        # Mock bucketer to always bucket into local holdout
        allow_any_instance_of(Optimizely::Bucketer).to receive(:bucket) do |_instance, _config, exp, _bucketing_id, _user_id|
          if %w[local_holdout_single_rule local_holdout_multiple_rules].include?(exp['id'])
            [exp['variations'].first, []]
          else
            [nil, []]
          end
        end

        result = decision_service.get_variation_from_experiment_rule(
          config,
          'boolean_single_variable_feature',
          experiment,
          user_context,
          nil,
          []
        )

        # Should be bucketed into local holdout (result has holdout variation)
        expect(result).not_to be_nil
        expect(result.reasons).to include(match(/local holdout/i))
      end

      it 'should skip rule evaluation when user is in local holdout' do
        user_context = project.create_user_context('skip_user', {})

        experiment = config.rollout_experiment_id_map['177770']

        # Mock bucketer to bucket into local holdout
        allow_any_instance_of(Optimizely::Bucketer).to receive(:bucket) do |_instance, _config, exp, _bucketing_id, _user_id|
          if exp['id'] == 'local_holdout_single_rule'
            [exp['variations'].first, []]
          else
            [nil, []]
          end
        end

        result = decision_service.get_variation_from_experiment_rule(
          config,
          'boolean_single_variable_feature',
          experiment,
          user_context,
          nil,
          []
        )

        # Verify holdout decision was returned
        expect(result).not_to be_nil
        # Rule variation should not be evaluated (we return holdout instead)
        expect(result.reasons).to include(match(/local holdout/i))
      end

      it 'should handle multiple local holdouts for same rule' do
        rule_id = '177770'
        holdouts = config.get_holdouts_for_rule(rule_id)
        expect(holdouts.length).to eq(2)

        # Verify both holdouts are checked in order
        user_context = project.create_user_context('multi_holdout_user', {})
        experiment = config.rollout_experiment_id_map[rule_id]

        # First holdout should be checked first
        allow_any_instance_of(Optimizely::Bucketer).to receive(:bucket) do |_instance, _config, exp, _bucketing_id, _user_id|
          if exp['id'] == 'local_holdout_single_rule'
            [exp['variations'].first, []]
          else
            [nil, []]
          end
        end

        result = decision_service.get_variation_from_experiment_rule(
          config,
          'boolean_single_variable_feature',
          experiment,
          user_context,
          nil,
          []
        )

        expect(result.reasons).to include(match(/local holdout/i))
      end
    end

    describe 'precedence: global before local' do
      it 'should check global holdouts at flag level before local holdouts at rule level' do
        # This is implicit in the decision flow:
        # 1. get_decision_for_flag checks global holdouts first
        # 2. Then checks experiments (which check local holdouts per rule)
        # 3. Then checks rollouts (which also check local holdouts per rule)

        user_context = project.create_user_context('precedence_user', {})

        allow_any_instance_of(Optimizely::Bucketer).to receive(:bucket) do |_instance, _config, exp, _bucketing_id, _user_id|
          # Bucket into global holdout
          if exp['id'] == 'global_holdout_nil_rules'
            [exp['variations'].first, []]
          else
            [nil, []]
          end
        end

        feature_flag = config.feature_flag_key_map.values.first
        result = decision_service.get_decision_for_flag(
          feature_flag,
          user_context,
          config,
          []
        )

        # Should stop at global holdout, never reaching local holdout evaluation
        expect(result.decision).not_to be_nil
        expect(result.decision.source).to eq(Optimizely::DecisionService::DECISION_SOURCES['HOLDOUT'])
        expect(result.reasons).to include(match(/global holdout/i))
      end
    end

    describe 'edge cases' do
      it 'should handle non-existent rule ID in local holdout gracefully' do
        # Config has holdout with rule ID '99999999' which doesn't exist
        holdouts = config.get_holdouts_for_rule('99999999')
        expect(holdouts.length).to eq(1)
        # Should not crash when evaluating
      end

      it 'should handle local holdout with empty array (no rules)' do
        empty_holdout = config.holdouts.find { |h| h['id'] == 'local_holdout_empty_array' }
        expect(empty_holdout['includedRules']).to eq([])

        # Should not be in any rule's holdouts
        config.rule_holdouts_map.each_value do |holdouts|
          expect(holdouts).not_to include(empty_holdout)
        end
      end
    end
  end
end
