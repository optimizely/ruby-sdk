# frozen_string_literal: true

require 'spec_helper'

describe Optimizely::Project do
  let(:datafile) { '{"version": "4", "experiments": [], "groups": [], "events": [], "featureFlags": []}' }
  let(:different_datafile) { '{"version": "4", "experiments": [{"id": "test"}], "groups": [], "events": [], "featureFlags": []}' }

  describe '.get_or_create_instance' do
    after do
      # Clean up cache after each test
      Optimizely::Project.clear_instance_cache!
    end

    it 'returns the same instance for identical datafiles' do
      instance1 = Optimizely::Project.get_or_create_instance(datafile: datafile)
      instance2 = Optimizely::Project.get_or_create_instance(datafile: datafile)

      expect(instance1).to be(instance2)
      expect(Optimizely::Project.cached_instance_count).to eq(1)
    end

    it 'returns different instances for different datafiles' do
      instance1 = Optimizely::Project.get_or_create_instance(datafile: datafile)
      instance2 = Optimizely::Project.get_or_create_instance(datafile: different_datafile)

      expect(instance1).not_to be(instance2)
      expect(Optimizely::Project.cached_instance_count).to eq(2)
    end

    it 'does not cache instances with sdk_key' do
      instance1 = Optimizely::Project.get_or_create_instance(datafile: datafile, sdk_key: 'test_key')
      instance2 = Optimizely::Project.get_or_create_instance(datafile: datafile, sdk_key: 'test_key')

      expect(instance1).not_to be(instance2)
      expect(Optimizely::Project.cached_instance_count).to eq(0)
    end

    it 'does not cache instances with custom config_manager' do
      config_manager = double('config_manager')
      allow(config_manager).to receive(:config)
      allow(config_manager).to receive(:sdk_key)

      instance1 = Optimizely::Project.get_or_create_instance(datafile: datafile, config_manager: config_manager)
      instance2 = Optimizely::Project.get_or_create_instance(datafile: datafile, config_manager: config_manager)

      expect(instance1).not_to be(instance2)
      expect(Optimizely::Project.cached_instance_count).to eq(0)
    end

    it 'removes instances from cache when closed' do
      instance = Optimizely::Project.get_or_create_instance(datafile: datafile)
      expect(Optimizely::Project.cached_instance_count).to eq(1)

      instance.close
      expect(Optimizely::Project.cached_instance_count).to eq(0)
    end

    it 'creates new instance if cached instance is stopped' do
      instance1 = Optimizely::Project.get_or_create_instance(datafile: datafile)
      instance1.close

      instance2 = Optimizely::Project.get_or_create_instance(datafile: datafile)
      expect(instance1).not_to be(instance2)
      expect(Optimizely::Project.cached_instance_count).to eq(1)
    end

    it 'considers different options when caching' do
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

  describe '.clear_instance_cache!' do
    it 'closes all cached instances and clears the cache' do
      instance1 = Optimizely::Project.get_or_create_instance(datafile: datafile)
      instance2 = Optimizely::Project.get_or_create_instance(datafile: different_datafile)

      expect(Optimizely::Project.cached_instance_count).to eq(2)
      expect(instance1.stopped).to be_falsy
      expect(instance2.stopped).to be_falsy

      Optimizely::Project.clear_instance_cache!

      expect(Optimizely::Project.cached_instance_count).to eq(0)
      expect(instance1.stopped).to be_truthy
      expect(instance2.stopped).to be_truthy
    end
  end

  describe 'memory leak prevention' do
    it 'prevents memory leaks from repeated Project creation' do
      initial_thread_count = Thread.list.size

      # Simulate the problematic pattern - repeated Project.new calls
      100.times do
        # Using get_or_create_instance should not create new threads each time
        Optimizely::Project.get_or_create_instance(datafile: datafile)
      end

      # Should only have created one cached instance
      expect(Optimizely::Project.cached_instance_count).to eq(1)

      # Thread count should not have grown significantly
      # (allowing for some variance due to test framework threads)
      expect(Thread.list.size).to be < initial_thread_count + 10

      Optimizely::Project.clear_instance_cache!
    end
  end
end
