# frozen_string_literal: true

require 'spec_helper'
require 'optimizely/cmab/cmab_service'
require 'optimizely/odp/lru_cache'
require 'optimizely/cmab/cmab_client'
require 'optimizely/decide/optimizely_decide_option'

describe Optimizely::DefaultCmabService do
  let(:mock_cmab_cache) { instance_double(Optimizely::LRUCache) }
  let(:mock_cmab_client) { instance_double(Optimizely::DefaultCmabClient) }
  let(:mock_logger) { double('logger') }
  let(:cmab_service) { described_class.new(mock_cmab_cache, mock_cmab_client, mock_logger) }

  let(:mock_project_config) { double('project_config') }
  let(:mock_user_context) { double('user_context') }
  let(:user_id) { 'user123' }
  let(:rule_id) { 'exp1' }
  let(:user_attributes) { {'age' => 25, 'location' => 'USA'} }

  let(:mock_experiment) { {'cmab' => {'attributeIds' => %w[66 77]}} }
  let(:mock_attr1) { double('attribute', key: 'age') }
  let(:mock_attr2) { double('attribute', key: 'location') }

  before do
    allow(mock_user_context).to receive(:user_id).and_return(user_id)
    allow(mock_user_context).to receive(:user_attributes).and_return(user_attributes)

    allow(mock_project_config).to receive(:experiment_id_map).and_return({rule_id => mock_experiment})
    allow(mock_project_config).to receive(:attribute_id_map).and_return({
                                                                          '66' => mock_attr1,
                                                                          '77' => mock_attr2
                                                                        })
  end

  describe '#get_decision' do
    it 'returns decision from cache when valid' do
      expected_key = cmab_service.send(:get_cache_key, user_id, rule_id)
      expected_attributes = {'age' => 25, 'location' => 'USA'}
      expected_hash = cmab_service.send(:hash_attributes, expected_attributes)

      cached_value = Optimizely::CmabCacheValue.new(
        attributes_hash: expected_hash,
        variation_id: 'varA',
        cmab_uuid: 'uuid-123'
      )

      allow(mock_cmab_cache).to receive(:lookup).with(expected_key).and_return(cached_value)

      decision = cmab_service.get_decision(mock_project_config, mock_user_context, rule_id, [])

      expect(mock_cmab_cache).to have_received(:lookup).with(expected_key)
      expect(decision.variation_id).to eq('varA')
      expect(decision.cmab_uuid).to eq('uuid-123')
    end

    it 'ignores cache when option given' do
      allow(mock_cmab_client).to receive(:fetch_decision).and_return('varB')
      expected_attributes = {'age' => 25, 'location' => 'USA'}

      decision = cmab_service.get_decision(
        mock_project_config,
        mock_user_context,
        rule_id,
        [Optimizely::Decide::OptimizelyDecideOption::IGNORE_CMAB_CACHE]
      )

      expect(decision.variation_id).to eq('varB')
      expect(decision.cmab_uuid).to be_a(String)
      expect(mock_cmab_client).to have_received(:fetch_decision).with(
        rule_id,
        user_id,
        expected_attributes,
        decision.cmab_uuid
      )
    end

    it 'invalidates user cache when option given' do
      allow(mock_cmab_client).to receive(:fetch_decision).and_return('varC')
      allow(mock_cmab_cache).to receive(:lookup).and_return(nil)
      allow(mock_cmab_cache).to receive(:remove)
      allow(mock_cmab_cache).to receive(:save)

      cmab_service.get_decision(
        mock_project_config,
        mock_user_context,
        rule_id,
        [Optimizely::Decide::OptimizelyDecideOption::INVALIDATE_USER_CMAB_CACHE]
      )

      key = cmab_service.send(:get_cache_key, user_id, rule_id)
      expect(mock_cmab_cache).to have_received(:remove).with(key)
    end

    it 'resets cache when option given' do
      allow(mock_cmab_client).to receive(:fetch_decision).and_return('varD')
      allow(mock_cmab_cache).to receive(:reset)
      allow(mock_cmab_cache).to receive(:lookup).and_return(nil)
      allow(mock_cmab_cache).to receive(:save)

      decision = cmab_service.get_decision(
        mock_project_config,
        mock_user_context,
        rule_id,
        [Optimizely::Decide::OptimizelyDecideOption::RESET_CMAB_CACHE]
      )

      expect(mock_cmab_cache).to have_received(:reset)
      expect(decision.variation_id).to eq('varD')
      expect(decision.cmab_uuid).to be_a(String)
    end

    it 'fetches new decision when hash changes' do
      old_cached_value = Optimizely::CmabCacheValue.new(
        attributes_hash: 'old_hash',
        variation_id: 'varA',
        cmab_uuid: 'uuid-123'
      )

      allow(mock_cmab_cache).to receive(:lookup).and_return(old_cached_value)
      allow(mock_cmab_cache).to receive(:remove)
      allow(mock_cmab_cache).to receive(:save)
      allow(mock_cmab_client).to receive(:fetch_decision).and_return('varE')

      expected_attributes = {'age' => 25, 'location' => 'USA'}
      cmab_service.send(:hash_attributes, expected_attributes)
      expected_key = cmab_service.send(:get_cache_key, user_id, rule_id)

      decision = cmab_service.get_decision(mock_project_config, mock_user_context, rule_id, [])

      expect(mock_cmab_cache).to have_received(:remove).with(expected_key)
      expect(mock_cmab_cache).to have_received(:save).with(
        expected_key,
        an_instance_of(Optimizely::CmabCacheValue)
      )
      expect(decision.variation_id).to eq('varE')
      expect(mock_cmab_client).to have_received(:fetch_decision).with(
        rule_id,
        user_id,
        expected_attributes,
        decision.cmab_uuid
      )
    end

    it 'only passes cmab attributes to client' do
      allow(mock_user_context).to receive(:user_attributes).and_return({
                                                                         'age' => 25,
                                                                         'location' => 'USA',
                                                                         'extra_attr' => 'value',
                                                                         'another_extra' => 123
                                                                       })
      allow(mock_cmab_client).to receive(:fetch_decision).and_return('varF')

      decision = cmab_service.get_decision(
        mock_project_config,
        mock_user_context,
        rule_id,
        [Optimizely::Decide::OptimizelyDecideOption::IGNORE_CMAB_CACHE]
      )

      # Verify only age and location are passed
      expect(mock_cmab_client).to have_received(:fetch_decision).with(
        rule_id,
        user_id,
        {'age' => 25, 'location' => 'USA'},
        decision.cmab_uuid
      )
    end
  end

  describe '#filter_attributes' do
    it 'returns correct subset of attributes' do
      filtered = cmab_service.send(:filter_attributes, mock_project_config, mock_user_context, rule_id)

      expect(filtered['age']).to eq(25)
      expect(filtered['location']).to eq('USA')
    end

    it 'returns empty hash when no cmab config' do
      allow(mock_project_config).to receive(:experiment_id_map).and_return({rule_id => {'cmab' => nil}})

      filtered = cmab_service.send(:filter_attributes, mock_project_config, mock_user_context, rule_id)

      expect(filtered).to eq({})
    end

    it 'returns empty hash when experiment not found' do
      allow(mock_project_config).to receive(:experiment_id_map).and_return({})

      filtered = cmab_service.send(:filter_attributes, mock_project_config, mock_user_context, rule_id)

      expect(filtered).to eq({})
    end
  end

  describe '#hash_attributes' do
    it 'produces stable output regardless of key order' do
      attrs1 = {'b' => 2, 'a' => 1}
      attrs2 = {'a' => 1, 'b' => 2}

      hash1 = cmab_service.send(:hash_attributes, attrs1)
      hash2 = cmab_service.send(:hash_attributes, attrs2)

      expect(hash1).to eq(hash2)
    end
  end

  describe '#get_cache_key' do
    it 'generates correct cache key format' do
      key = cmab_service.send(:get_cache_key, 'user123', 'exp1')

      expect(key).to eq('7-user123-exp1')
    end
  end

  describe '#fetch_decision' do
    it 'generates uuid and calls client' do
      allow(mock_cmab_client).to receive(:fetch_decision).and_return('varX')
      attributes = {'age' => 25}

      decision = cmab_service.send(:fetch_decision, rule_id, user_id, attributes)

      expect(decision.variation_id).to eq('varX')
      expect(decision.cmab_uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      expect(mock_cmab_client).to have_received(:fetch_decision).with(
        rule_id,
        user_id,
        attributes,
        decision.cmab_uuid
      )
    end
  end
end
