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
require 'spec_helper'

describe Optimizely::SemanticVersion do
  describe 'compare_user_version_with_target_version' do
    # ==0 scenarios
    versions = [
      ['2.0', '2.0.1'],
      ['2.0.0', '2.0.0'],
      ['2.9', '2.9.1'],
      ['2.9.9', '2.9.9'],
      ['2.9.9-beta', '2.9.9-beta'],
      ['2.1', '2.1.0'],
      ['2.1', '2.1.215'],
      ['2', '2.12'],
      ['2', '2.785.13']
    ]

    versions.each do |target_version, user_version|
      it("should return 0 for target version: #{target_version} and user version: #{user_version}") do
        res = Optimizely::SemanticVersion.compare_user_version_with_target_version(
          target_version, user_version
        )
        expect(res).to eq(0)
      end
    end

    # >0 scenarios
    versions = [
      ['2.0.0', '2.0.1'],
      ['2.0', '3.0.1'],
      ['2.0', '2.9.1'],
      ['2.9.0', '2.9.1'],
      ['2.1.2', '2.1.3-beta'],
      ['2.1.2-beta', '2.1.2-release'],
      ['2.1.3-beta', '2.1.3']
    ]

    versions.each do |target_version, user_version|
      it("should return > 0 for target version: #{target_version} and user version: #{user_version}") do
        res = Optimizely::SemanticVersion.compare_user_version_with_target_version(
          target_version, user_version
        )
        expect(res).to be > 0
      end
    end

    # <0 scenarios
    versions = [
      ['2.0.1', '2.0.0'],
      ['3.0', '2.0.1'],
      ['2.3', '2.0.1'],
      ['2.3.5', '2.3.1'],
      ['2.9.8', '2.9'],
      ['2.1.2-release', '2.1.2-beta'],
      ['2.1.3', '2.1.3-beta']
    ]

    versions.each do |target_version, user_version|
      it("should return < 0 for target version: #{target_version} and user version: #{user_version}") do
        res = Optimizely::SemanticVersion.compare_user_version_with_target_version(
          target_version, user_version
        )
        expect(res).to be < 0
      end
    end

    # invalid semantic version
    versions = [
      '-', '.', '..', '+', '+test', ' ', '2 .3. 0', '2.', '.2.2', '3.7.2.2', '3.x', ',', '+build-prerelease'
    ]

    versions.each do |user_version|
      target_version = '2.1.0'
      it("should raise for target version: #{target_version} and user version: #{user_version}") do
        expect do
          Optimizely::SemanticVersion.compare_user_version_with_target_version(
            target_version, user_version
          )
        end.to raise_error(Optimizely::InvalidSemanticVersion)
      end
    end

    # invalid data type
    versions = [
      ['2.0.1', true],
      [0, '2.0.1']
    ]

    versions.each do |target_version, user_version|
      it("should raise for target version: #{target_version} and user version: #{user_version}") do
        expect do
          Optimizely::SemanticVersion.compare_user_version_with_target_version(
            target_version, user_version
          )
        end.to raise_error(Optimizely::InvalidAttributeType)
      end
    end
  end
end
