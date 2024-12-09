# frozen_string_literal: true

require 'spec_helper'
require 'rspec'

RSpec.describe Optimizely::UserProfileTracker do
  let(:user_id) { 'test_user' }
  let(:mock_user_profile_service) { instance_double('UserProfileService') }
  let(:mock_logger) { instance_double('Logger') }
  let(:user_profile_tracker) { described_class.new(user_id, mock_user_profile_service, mock_logger) }

  describe '#initialize' do
    it 'initializes with a user ID and default values' do
      tracker = described_class.new(user_id)
      expect(tracker.user_profile[:user_id]).to eq(user_id)
      expect(tracker.user_profile[:experiment_bucket_map]).to eq({})
    end

    it 'accepts a user profile service and logger' do
      expect(user_profile_tracker.instance_variable_get(:@user_profile_service)).to eq(mock_user_profile_service)
      expect(user_profile_tracker.instance_variable_get(:@logger)).to eq(mock_logger)
    end
  end

  describe '#load_user_profile' do
    it 'loads the user profile from the service if provided' do
      expected_profile = {
        user_id: user_id,
        experiment_bucket_map: { '111127' => { variation_id: '111128' } }
      }
      allow(mock_user_profile_service).to receive(:lookup).with(user_id).and_return(expected_profile)
      user_profile_tracker.load_user_profile
      expect(user_profile_tracker.user_profile).to eq(expected_profile)
    end

    it 'handles errors during lookup and logs them' do
      allow(mock_user_profile_service).to receive(:lookup).with(user_id).and_raise(StandardError.new('lookup error'))
      allow(mock_logger).to receive(:log)

      reasons = []
      user_profile_tracker.load_user_profile(reasons)
      expect(reasons).to include("Error while looking up user profile for user ID 'test_user': lookup error.")
      expect(mock_logger).to have_received(:log).with(Logger::ERROR, "Error while looking up user profile for user ID 'test_user': lookup error.")
    end

    it 'does nothing if reasons array is nil' do
      expect(mock_user_profile_service).not_to receive(:lookup)
      user_profile_tracker.load_user_profile(nil)
    end
  end

  describe '#update_user_profile' do
    let(:experiment_id) { '111127' }
    let(:variation_id) { '111128' }

    before do
      allow(mock_logger).to receive(:log)
    end

    it 'updates the experiment bucket map with the given experiment and variation IDs' do
      user_profile_tracker.update_user_profile(experiment_id, variation_id)

      # Verify the experiment and variation were added
      expect(user_profile_tracker.user_profile[:experiment_bucket_map][experiment_id][:variation_id]).to eq(variation_id)
      # Verify the profile_updated flag was set
      expect(user_profile_tracker.instance_variable_get(:@profile_updated)).to eq(true)
      # Verify a log message was recorded
      expect(mock_logger).to have_received(:log).with(Logger::INFO, "Updated variation ID #{variation_id} of experiment ID #{experiment_id} for user 'test_user'.")
    end
  end

  describe '#save_user_profile' do
    it 'saves the user profile if updates were made and service is available' do
      allow(mock_user_profile_service).to receive(:save)
      allow(mock_logger).to receive(:log)

      user_profile_tracker.update_user_profile('111127', '111128')
      user_profile_tracker.save_user_profile

      expect(mock_user_profile_service).to have_received(:save).with(user_profile_tracker.user_profile)
      expect(mock_logger).to have_received(:log).with(Logger::INFO, "Saved user profile for user 'test_user'.")
    end

    it 'does not save the user profile if no updates were made' do
      allow(mock_user_profile_service).to receive(:save)

      user_profile_tracker.save_user_profile
      expect(mock_user_profile_service).not_to have_received(:save)
    end

    it 'handles errors during save and logs them' do
      allow(mock_user_profile_service).to receive(:save).and_raise(StandardError.new('save error'))
      allow(mock_logger).to receive(:log)

      user_profile_tracker.update_user_profile('111127', '111128')
      user_profile_tracker.save_user_profile

      expect(mock_logger).to have_received(:log).with(Logger::ERROR, "Failed to save user profile for user 'test_user': save error.")
    end
  end
end
