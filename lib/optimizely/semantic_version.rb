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
      target.include? SEMVER_PRE_RELEASE
    end

    def split_semantic_version(target)
      target_prefix = target
      target_suffix = ''
      target_parts = []

      raise InvalidSemanticVersion if target.include? ' '

      if pre_release?(target)
        target_parts = target.split(SEMVER_PRE_RELEASE)
      elsif target.include? SEMVER_BUILD
        target_parts = target.split(SEMVER_BUILD)
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
      raise InvalidAttributeType unless target_version.is_a? String
      raise InvalidAttributeType unless user_version.is_a? String

      target_version_parts = split_semantic_version(target_version)
      user_version_parts = split_semantic_version(user_version)
      user_version_parts_len = user_version_parts.length if user_version_parts

      # Up to the precision of targetedVersion, expect version to match exactly.
      target_version_parts.each_with_index do |_item, idx|
        if user_version_parts_len <= idx
          # even if they are equal at this point. if the target is a prerelease
          # then it must be greater than the pre release.
          return 1 if pre_release?(target_version)

          return -1

        elsif !Helpers::Validator.string_numeric? user_version_parts[idx]
          # compare strings
          return -1 if user_version_parts[idx] < target_version_parts[idx]
          return 1 if user_version_parts[idx] > target_version_parts[idx]

        else
          user_version_part = user_version_parts[idx].to_i
          target_version_part = target_version_parts[idx].to_i

          return 1 if user_version_part > target_version_part
          return -1 if user_version_part < target_version_part
        end
      end

      return -1 if pre_release?(user_version) && !pre_release?(target_version)

      0
    end
  end
end
