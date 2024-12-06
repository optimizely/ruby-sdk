# frozen_string_literal: true

require_relative 'logger'

module Optimizely
  class UserProfileTracker
    attr_reader :user_profile

    def initialize(user_id, user_profile_service = nil, logger = nil)
      @user_id = user_id
      @user_profile_service = user_profile_service
      @logger = logger || NoOpLogger.new
      @profile_updated = false
      @user_profile = {
        user_id: user_id,
        experiment_bucket_map: {}
      }
    end

    def load_user_profile(reasons = [], error_handler = nil)
      return if reasons.nil?

      begin
        @user_profile = @user_profile_service.lookup(@user_id) || @user_profile
      rescue => e
        message = "Error while loading user profile in user profile tracker for user ID '#{@user_id}': #{e}."
        reasons << e.message
        @logger.log(Logger::ERROR, message)
        error_handler&.handle_error(e)
      end
    end

    def update_user_profile(experiment_id, variation_id)
      user_id = @user_profile[:user_id]
      begin
        @user_profile[:experiment_bucket_map][experiment_id] = {
          variation_id: variation_id
        }
        @profile_updated = true
        @logger.log(Logger::INFO, "Updated variation ID #{variation_id} of experiment ID #{experiment_id} for user '#{user_id}'.")
      rescue => e
        @logger.log(Logger::ERROR, "Error while updating user profile for user ID '#{user_id}': #{e}.")
      end
    end

    def save_user_profile(error_handler = nil)
      return unless @profile_updated && @user_profile_service

      begin
        @user_profile_service.save(@user_profile)
        @logger.log(Logger::INFO, "Saved user profile for user '#{@user_profile[:user_id]}'.")
      rescue => e
        @logger.log(Logger::ERROR, "Failed to save user profile for user '#{@user_profile[:user_id]}': #{e}.")
        error_handler&.handle_error(e)
      end
    end
  end
end
