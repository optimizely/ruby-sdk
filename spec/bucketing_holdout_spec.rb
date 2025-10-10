# frozen_string_literal: true

#
#    Copyright 2025 Optimizely and contributors
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
require 'optimizely/bucketer'
require 'optimizely/error_handler'
require 'optimizely/logger'

# Helper class for testing with controlled bucket values
class TestBucketer < Optimizely::Bucketer
  def initialize(logger)
    super(logger)
    @bucket_values = []
    @bucket_index = 0
  end

  def bucket_values(values)
    @bucket_values = values
    @bucket_index = 0
  end

  def generate_bucket_value(bucketing_id)
    return super(bucketing_id) if @bucket_values.empty?

    value = @bucket_values[@bucket_index]
    @bucket_index = (@bucket_index + 1) % @bucket_values.length
    value
  end
end

describe 'Optimizely::Bucketer - Holdout Tests' do
  let(:error_handler) { Optimizely::NoOpErrorHandler.new }
  let(:spy_logger) { spy('logger') }
  let(:test_user_id) { 'test_user_id' }
  let(:test_bucketing_id) { 'test_bucketing_id' }
  let(:config) do
    Optimizely::DatafileProjectConfig.new(
      OptimizelySpec::CONFIG_BODY_WITH_HOLDOUTS_JSON,
      spy_logger,
      error_handler
    )
  end
  let(:test_bucketer) { TestBucketer.new(spy_logger) }

  before do
    # Verify that the config contains holdouts
    expect(config.holdouts).not_to be_nil
    expect(config.holdouts.length).to be > 0
  end

  describe '#bucket with holdouts' do
    it 'should bucket user within valid traffic allocation range' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Set bucket value to be within first variation's traffic allocation (0-5000 range)
      test_bucketer.set_bucket_values([2500])

      variation, _reasons = test_bucketer.bucket(config, holdout, test_bucketing_id, test_user_id)

      expect(variation).not_to be_nil
      expect(variation['id']).to eq('var_1')
      expect(variation['key']).to eq('control')

      # Verify logging
      expect(spy_logger).to have_received(:log).with(
        Logger::DEBUG,
        "Assigned bucket 2500 to user '#{test_user_id}' with bucketing ID: '#{test_bucketing_id}'."
      )
    end

    it 'should return nil when user is outside traffic allocation range' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Modify traffic allocation to be smaller by creating a modified holdout
      modified_holdout = OptimizelySpec.deep_clone(holdout)
      modified_holdout['trafficAllocation'][0]['endOfRange'] = 1000

      # Set bucket value outside traffic allocation range
      test_bucketer.set_bucket_values([1500])

      variation, _reasons = test_bucketer.bucket(config, modified_holdout, test_bucketing_id, test_user_id)

      expect(variation).to be_nil

      # Verify user was assigned bucket value but no variation was found
      expect(spy_logger).to have_received(:log).with(
        Logger::DEBUG,
        "Assigned bucket 1500 to user '#{test_user_id}' with bucketing ID: '#{test_bucketing_id}'."
      )
    end

    it 'should return nil when holdout has no traffic allocation' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Clear traffic allocation
      modified_holdout = OptimizelySpec.deep_clone(holdout)
      modified_holdout['trafficAllocation'] = []

      test_bucketer.set_bucket_values([5000])

      variation, _reasons = test_bucketer.bucket(config, modified_holdout, test_bucketing_id, test_user_id)

      expect(variation).to be_nil

      # Verify bucket was assigned but no variation found
      expect(spy_logger).to have_received(:log).with(
        Logger::DEBUG,
        "Assigned bucket 5000 to user '#{test_user_id}' with bucketing ID: '#{test_bucketing_id}'."
      )
    end

    it 'should return nil when traffic allocation points to invalid variation ID' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Set traffic allocation to point to non-existent variation
      modified_holdout = OptimizelySpec.deep_clone(holdout)
      modified_holdout['trafficAllocation'][0]['entityId'] = 'invalid_variation_id'

      test_bucketer.set_bucket_values([5000])

      variation, _reasons = test_bucketer.bucket(config, modified_holdout, test_bucketing_id, test_user_id)

      expect(variation).to be_nil

      # Verify bucket was assigned
      expect(spy_logger).to have_received(:log).with(
        Logger::DEBUG,
        "Assigned bucket 5000 to user '#{test_user_id}' with bucketing ID: '#{test_bucketing_id}'."
      )
    end

    it 'should return nil when holdout has no variations' do
      holdout = config.get_holdout('holdout_empty_1')
      expect(holdout).not_to be_nil
      expect(holdout['variations']&.length || 0).to eq(0)

      test_bucketer.set_bucket_values([5000])

      variation, _reasons = test_bucketer.bucket(config, holdout, test_bucketing_id, test_user_id)

      expect(variation).to be_nil

      # Verify bucket was assigned
      expect(spy_logger).to have_received(:log).with(
        Logger::DEBUG,
        "Assigned bucket 5000 to user '#{test_user_id}' with bucketing ID: '#{test_bucketing_id}'."
      )
    end

    it 'should return nil when holdout has empty key' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Clear holdout key
      modified_holdout = OptimizelySpec.deep_clone(holdout)
      modified_holdout['key'] = ''

      test_bucketer.set_bucket_values([5000])

      variation, _reasons = test_bucketer.bucket(config, modified_holdout, test_bucketing_id, test_user_id)

      # Should return nil for invalid experiment key
      expect(variation).to be_nil
    end

    it 'should return nil when holdout has null key' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Set holdout key to nil
      modified_holdout = OptimizelySpec.deep_clone(holdout)
      modified_holdout['key'] = nil

      test_bucketer.set_bucket_values([5000])

      variation, _reasons = test_bucketer.bucket(config, modified_holdout, test_bucketing_id, test_user_id)

      # Should return nil for null experiment key
      expect(variation).to be_nil
    end

    it 'should bucket user into first variation with multiple variations' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Verify holdout has multiple variations
      expect(holdout['variations'].length).to be >= 2

      # Test user buckets into first variation
      test_bucketer.set_bucket_values([2500])
      variation, _reasons = test_bucketer.bucket(config, holdout, test_bucketing_id, test_user_id)

      expect(variation).not_to be_nil
      expect(variation['id']).to eq('var_1')
      expect(variation['key']).to eq('control')
    end

    it 'should bucket user into second variation with multiple variations' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Verify holdout has multiple variations
      expect(holdout['variations'].length).to be >= 2
      expect(holdout['variations'][0]['id']).to eq('var_1')
      expect(holdout['variations'][1]['id']).to eq('var_2')

      # Test user buckets into second variation (bucket value 7500 should be in 5000-10000 range)
      test_bucketer.set_bucket_values([7500])
      variation, _reasons = test_bucketer.bucket(config, holdout, test_bucketing_id, test_user_id)

      expect(variation).not_to be_nil
      expect(variation['id']).to eq('var_2')
      expect(variation['key']).to eq('treatment')
    end

    it 'should handle edge case boundary values correctly' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Modify traffic allocation to be 5000 (50%)
      modified_holdout = OptimizelySpec.deep_clone(holdout)
      modified_holdout['trafficAllocation'][0]['endOfRange'] = 5000

      # Test exact boundary value (should be included)
      test_bucketer.set_bucket_values([4999])
      variation, _reasons = test_bucketer.bucket(config, modified_holdout, test_bucketing_id, test_user_id)

      expect(variation).not_to be_nil
      expect(variation['id']).to eq('var_1')

      # Test value just outside boundary (should not be included)
      test_bucketer.set_bucket_values([5000])
      variation, _reasons = test_bucketer.bucket(config, modified_holdout, test_bucketing_id, test_user_id)

      expect(variation).to be_nil
    end

    it 'should produce consistent results with same inputs' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Create a real bucketer (not test bucketer) for consistent hashing
      real_bucketer = Optimizely::Bucketer.new(spy_logger)
      variation1, _reasons1 = real_bucketer.bucket(config, holdout, test_bucketing_id, test_user_id)
      variation2, _reasons2 = real_bucketer.bucket(config, holdout, test_bucketing_id, test_user_id)

      # Results should be identical
      if variation1
        expect(variation2).not_to be_nil
        expect(variation1['id']).to eq(variation2['id'])
        expect(variation1['key']).to eq(variation2['key'])
      else
        expect(variation2).to be_nil
      end
    end

    it 'should handle different bucketing IDs without exceptions' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      # Create a real bucketer (not test bucketer) for real hashing behavior
      real_bucketer = Optimizely::Bucketer.new(spy_logger)

      # These calls should not raise exceptions
      expect do
        real_bucketer.bucket(config, holdout, 'bucketingId1', test_user_id)
        real_bucketer.bucket(config, holdout, 'bucketingId2', test_user_id)
      end.not_to raise_error
    end

    it 'should populate decision reasons properly' do
      holdout = config.get_holdout('holdout_1')
      expect(holdout).not_to be_nil

      test_bucketer.set_bucket_values([5000])
      _variation, reasons = test_bucketer.bucket(config, holdout, test_bucketing_id, test_user_id)

      expect(reasons).not_to be_nil
      # Decision reasons should be populated from the bucketing process
      # The exact content depends on whether the user was bucketed or not
    end
  end
end
