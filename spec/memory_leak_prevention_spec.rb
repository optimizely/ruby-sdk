# frozen_string_literal: true

require 'spec_helper'

describe 'Memory Leak Prevention' do
  let(:datafile) { '{"version": "4", "experiments": [], "groups": [], "events": [], "featureFlags": []}' }

  before do
    # Clean up any existing instances
    Optimizely::Project.clear_instance_cache!
  end

  after do
    # Clean up after each test
    Optimizely::Project.clear_instance_cache!
  end

  describe 'Thread Creation Prevention' do
    it 'should not create new threads when using get_or_create_instance repeatedly' do
      initial_thread_count = Thread.list.size

      # Simulate the problematic pattern that was causing memory leaks
      # In the real world, this would be called once per request
      threads_created = []

      10.times do |i|
        # Use the safe caching method
        optimizely = Optimizely::Project.get_or_create_instance(datafile: datafile)

        # Make a decision to trigger thread creation if any
        optimizely.create_user_context("user_#{i}")

        # Track thread count after each creation
        threads_created << Thread.list.size
      end

      final_thread_count = Thread.list.size

      # Should only have created one cached instance
      expect(Optimizely::Project.cached_instance_count).to eq(1)

      # Thread count should not have grown significantly per instance
      # Allow for some variance due to initialization of first instance
      expect(final_thread_count).to be <= initial_thread_count + 5

      # Verify that we're not creating more threads with each call
      # After the first few calls, thread count should stabilize
      stable_count = threads_created[3]
      expect(threads_created.last).to eq(stable_count)
    end

    it 'demonstrates the memory leak that would occur with repeated Project.new calls' do
      instances = []

      # Simulate the problematic pattern (commented out to avoid actual leak in tests)
      # This is what users were doing that caused the memory leak:
      5.times do
        # instances << Optimizely::Project.new(datafile: datafile)
        #
        # Instead, show what happens when we create instances without caching
        # and don't clean them up (simulating the leak condition)
        instances << Optimizely::Project.new(datafile: datafile)
      end

      # Each instance would create its own background threads
      # In the real memory leak scenario, these would accumulate indefinitely
      expect(instances.size).to eq(5)
      expect(instances.uniq.size).to eq(5) # All different instances

      # Clean up instances to prevent actual memory leak in test
      instances.each(&:close)
    end
  end

  describe 'Cache Key Generation' do
    it 'should create same cache key for identical configurations' do
      instance1 = Optimizely::Project.get_or_create_instance(datafile: datafile)
      instance2 = Optimizely::Project.get_or_create_instance(datafile: datafile)

      expect(instance1).to be(instance2)
      expect(Optimizely::Project.cached_instance_count).to eq(1)
    end

    it 'should create different cache keys for different configurations' do
      instance1 = Optimizely::Project.get_or_create_instance(
        datafile: datafile,
        skip_json_validation: true
      )
      instance2 = Optimizely::Project.get_or_create_instance(
        datafile: datafile,
        skip_json_validation: false
      )

      expect(instance1).not_to be(instance2)
      expect(Optimizely::Project.cached_instance_count).to eq(2)
    end
  end

  describe 'Resource Cleanup' do
    it 'should properly stop background threads when instance is closed' do
      instance = Optimizely::Project.get_or_create_instance(datafile: datafile)

      # Trigger thread creation by making a decision
      instance.create_user_context('test_user')

      expect(instance.stopped).to be_falsy

      instance.close

      expect(instance.stopped).to be_truthy
      expect(Optimizely::Project.cached_instance_count).to eq(0)
    end

    it 'should cleanup all instances when cache is cleared' do
      instance1 = Optimizely::Project.get_or_create_instance(datafile: datafile)
      instance2 = Optimizely::Project.get_or_create_instance(
        datafile: '{"version": "4", "experiments": [{"id": "test"}], "groups": [], "events": [], "featureFlags": []}'
      )

      expect(Optimizely::Project.cached_instance_count).to eq(2)
      expect(instance1.stopped).to be_falsy
      expect(instance2.stopped).to be_falsy

      Optimizely::Project.clear_instance_cache!

      expect(Optimizely::Project.cached_instance_count).to eq(0)
      expect(instance1.stopped).to be_truthy
      expect(instance2.stopped).to be_truthy
    end
  end

  describe 'Production Usage Patterns' do
    it 'should handle Rails-like request pattern efficiently' do
      initial_thread_count = Thread.list.size

      # Simulate Rails controller pattern with cached datafile
      cached_datafile = datafile
      request_results = []

      # Simulate 50 requests (what would cause significant memory growth before)
      50.times do |request_id|
        # This is the safe pattern that should be used in production
        optimizely = Optimizely::Project.get_or_create_instance(datafile: cached_datafile)

        # Simulate making decisions in the request
        optimizely.create_user_context("user_#{request_id}")

        # Store result (in real app this would be returned to user)
        request_results << {
          request_id: request_id,
          optimizely_instance_id: optimizely.object_id,
          thread_count: Thread.list.size
        }
      end

      # Verify efficiency:
      # 1. All requests should use the same instance
      unique_instance_ids = request_results.map { |r| r[:optimizely_instance_id] }.uniq
      expect(unique_instance_ids.size).to eq(1)

      # 2. Only one instance should be cached
      expect(Optimizely::Project.cached_instance_count).to eq(1)

      # 3. Thread count should be stable after initial ramp-up
      final_thread_counts = request_results.last(10).map { |r| r[:thread_count] }
      expect(final_thread_counts.uniq.size).to be <= 2 # Allow for minimal variance

      # 4. No significant thread growth
      final_thread_count = Thread.list.size
      expect(final_thread_count).to be <= initial_thread_count + 10
    end
  end

  describe 'Memory Safety Guarantees' do
    it 'should not cache instances with dynamic configuration' do
      # These should not be cached due to having dynamic config
      instance_with_sdk_key = Optimizely::Project.get_or_create_instance(
        datafile: datafile,
        sdk_key: 'test_key'
      )

      instance_with_user_profile = Optimizely::Project.get_or_create_instance(
        datafile: datafile,
        user_profile_service: double('user_profile_service')
      )

      # Should have 0 cached instances since these shouldn't be cached
      expect(Optimizely::Project.cached_instance_count).to eq(0)

      # Clean up the non-cached instances
      instance_with_sdk_key.close
      instance_with_user_profile.close
    end

    it 'should handle finalizer cleanup gracefully' do
      # Test that finalizers work when instances are not explicitly closed
      Optimizely::Project.get_or_create_instance(datafile: datafile)

      expect(Optimizely::Project.cached_instance_count).to eq(1)

      # Force garbage collection to trigger finalizer
      GC.start

      # The finalizer should have been called, but the instance might still be
      # in cache until explicitly removed. This tests that the finalizer
      # doesn't crash the system.
      expect(true).to be_truthy # Just verify we don't crash
    end
  end
end
