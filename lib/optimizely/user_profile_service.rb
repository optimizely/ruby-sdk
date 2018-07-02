# frozen_string_literal: true

#
#    Copyright 2017, Optimizely and contributors
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

module Optimizely
  class BaseUserProfileService
    # Class encapsulating user profile service functionality.
    # Override with your own implementation for storing and retrieving user profiles.

    # Retrieve the Hash user profile associated with a given user ID.
    #
    # @param user_id - String user ID
    # @return [Hash] user profile.
    def lookup(user_id); end

    # Saves a given user profile.
    #
    # @param user_profile - Hash user profile.
    def save(user_profile); end
  end
end
