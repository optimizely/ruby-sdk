# frozen_string_literal: true

#
#    Copyright 2020, Optimizely and contributors
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

require_relative 'exceptions'

module Optimizely
  module SemanticVersion
    # Semantic Version Operators
    SEMVER_PRE_RELEASE = '-'
    SEMVER_BUILD = '+'

    module_function

    def pre_release?(target)
      # Method to check if the given version is a prerelease
      #
      # target - String representing semantic version
      #
      # Returns true if the given version is a prerelease
      #         false if it doesn't

      raise unless target.is_a? String

      prerelease_index = target.index(SEMVER_PRE_RELEASE)
      build_index = target.index(SEMVER_BUILD)

      return false if prerelease_index.nil?
      return true if build_index.nil?

      # when both operators are present prerelease should precede the build operator
      prerelease_index < build_index
    end

    def build?(target)
      # Method to check if the given version is a build
      #
      # target - String representing semantic version
      #
      # Returns true if the given version is a build
      #         false if it doesn't

      raise unless target.is_a? String

      prerelease_index = target.index(SEMVER_PRE_RELEASE)
      build_index = target.index(SEMVER_BUILD)

      return false if build_index.nil?
      return true if prerelease_index.nil?

      # when both operators are present build should precede the prerelease operator
      build_index < prerelease_index
    end

    def split_semantic_version(target)
      # Method to split the given version.
      #
      # target - String representing semantic version
      #
      # Returns List The array of version split into smaller parts i.e major, minor, patch etc,
      #         Exception if the given version is invalid.

      target_prefix = target
      target_suffix = ''
      target_parts = []

      raise InvalidSemanticVersion if target.include? ' '

      if pre_release?(target)
        target_parts = target.split(SEMVER_PRE_RELEASE, 2)
      elsif build? target
        target_parts = target.split(SEMVER_BUILD, 2)
      end

      unless target_parts.empty?
        target_prefix = target_parts[0].to_s
        target_suffix = target_parts[1..-1]
      end

      # expect a version string of the form x.y.z
      dot_count = target_prefix.count('.')
      raise InvalidSemanticVersion if dot_count > 2

      target_version_parts = target_prefix.split('.')
      raise InvalidSemanticVersion if target_version_parts.length != dot_count + 1

      target_version_parts.each do |part|
        raise InvalidSemanticVersion unless Helpers::Validator.string_numeric? part
      end

      target_version_parts.concat(target_suffix) if target_suffix.is_a?(Array)

      target_version_parts
    end

    def compare_user_version_with_target_version(target_version, user_version)
      # Compares target and user versions
      #
      # target_version - String representing target version
      # user_version - String representing user version

      # Returns boolean 0 if user version is equal to target version,
      #                 1 if user version is greater than target version,
      #                -1 if user version is less than target version.

      raise InvalidAttributeType unless target_version.is_a? String
      raise InvalidAttributeType unless user_version.is_a? String

      is_target_version_prerelease = pre_release?(target_version)
      is_user_version_prerelease = pre_release?(user_version)

      target_version_parts = split_semantic_version(target_version)
      user_version_parts = split_semantic_version(user_version)
      user_version_parts_len = user_version_parts.length if user_version_parts

      # Up to the precision of targetedVersion, expect version to match exactly.
      target_version_parts.each_with_index do |_item, idx|
        if user_version_parts_len <= idx
          # even if they are equal at this point. if the target is a prerelease
          # then user version must be greater than the pre release.
          return 1 if is_target_version_prerelease

          return -1

        elsif !Helpers::Validator.string_numeric? user_version_parts[idx]
          # compare strings
          if user_version_parts[idx] < target_version_parts[idx]
            return 1 if is_target_version_prerelease && !is_user_version_prerelease

            return -1

          elsif user_version_parts[idx] > target_version_parts[idx]
            return -1 if is_user_version_prerelease && !is_target_version_prerelease

            return 1
          end

        else
          user_version_part = user_version_parts[idx].to_i
          target_version_part = target_version_parts[idx].to_i

          return 1 if user_version_part > target_version_part
          return -1 if user_version_part < target_version_part
        end
      end

      return -1 if is_user_version_prerelease && !is_target_version_prerelease

      0
    end
  end
end
