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
require 'optimizely/decision_service'
require 'optimizely/error_handler'
require 'optimizely/logger'

describe 'Local Holdouts' do
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }

  describe 'DatafileProjectConfig local holdout classification' do
    let(:config_body_json) { OptimizelySpec::CONFIG_BODY_WITH_HOLDOUTS_JSON }
    let(:config) { Optimizely::DatafileProjectConfig.new(config_body_json, spy_logger, error_handler) }

    context 'when holdouts have no includedRules field (old datafile format)' do
      it 'treats holdouts as global (backward compatibility)' do
        # All holdouts in CONFIG_BODY_WITH_HOLDOUTS have no includedRules = nil = global
        running_holdouts = config.holdout_id_map.values
        global_holdouts = config.global_holdouts

        # Running holdouts: holdout_1, holdout_boolean_feature, holdout_empty_1, holdout_2 (holdout_3 is Inactive)
        expect(global_holdouts.length).to eq(running_holdouts.length)
        expect(config.rule_holdouts_map).to be_empty
      end
    end

    context 'with local holdouts config' do
      let(:local_config_json) { OptimizelySpec::CONFIG_BODY_WITH_LOCAL_HOLDOUTS_JSON }
      let(:local_config) { Optimizely::DatafileProjectConfig.new(local_config_json, spy_logger, error_handler) }

      it 'classifies holdout with nil includedRules as global' do
        global_holdouts = local_config.global_holdouts
        expect(global_holdouts.length).to eq(1)
        expect(global_holdouts.first['id']).to eq('global_holdout_1')
      end

      it 'classifies holdout with non-nil includedRules as local' do
        global_holdouts = local_config.global_holdouts
        # Only global_holdout_1 should be in global list, not local_holdout_1
        expect(global_holdouts.none? { |h| h['id'] == 'local_holdout_1' }).to be(true)
      end

      it 'populates rule_holdouts_map for local holdouts' do
        rule_holdouts_map = local_config.rule_holdouts_map
        expect(rule_holdouts_map).to have_key('111127')
        expect(rule_holdouts_map['111127'].length).to eq(1)
        expect(rule_holdouts_map['111127'].first['id']).to eq('local_holdout_1')
      end

      it 'get_holdouts_for_rule returns local holdouts for a rule' do
        holdouts = local_config.get_holdouts_for_rule('111127')
        expect(holdouts.length).to eq(1)
        expect(holdouts.first['key']).to eq('local_holdout_exp')
      end

      it 'get_holdouts_for_rule returns empty array for unknown rule' do
        holdouts = local_config.get_holdouts_for_rule('unknown_rule_id')
        expect(holdouts).to be_empty
      end

      it 'global_holdouts returns empty array when no global holdouts' do
        # Build a config with only a local holdout
        only_local = OptimizelySpec::VALID_CONFIG_BODY.merge(
          'holdouts' => [
            {
              'id' => 'local_only',
              'key' => 'local_only_holdout',
              'status' => 'Running',
              'audiences' => [],
              'audienceIds' => [],
              'audienceConditions' => [],
              'includedRules' => ['some_rule'],
              'variations' => [{'id' => 'v1', 'key' => 'off', 'featureEnabled' => false}],
              'trafficAllocation' => [{'entityId' => 'v1', 'endOfRange' => 10_000}]
            }
          ]
        )
        only_local_config = Optimizely::DatafileProjectConfig.new(JSON.dump(only_local), spy_logger, error_handler)

        expect(only_local_config.global_holdouts).to be_empty
        expect(only_local_config.rule_holdouts_map['some_rule'].length).to eq(1)
      end
    end
  end

  describe 'is_global? semantics via includedRules' do
    it 'treats nil includedRules as global (no field in datafile)' do
      holdout = {'id' => 'h1', 'key' => 'global', 'includedRules' => nil}
      expect(holdout['includedRules'].nil?).to be(true)
    end

    it 'treats non-nil includedRules as local even if empty' do
      holdout = {'id' => 'h2', 'key' => 'local_empty', 'includedRules' => []}
      expect(holdout['includedRules'].nil?).to be(false)
    end

    it 'treats non-nil includedRules with values as local' do
      holdout = {'id' => 'h3', 'key' => 'local', 'includedRules' => ['rule1']}
      expect(holdout['includedRules'].nil?).to be(false)
    end
  end
end
