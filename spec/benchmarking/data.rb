#
#    Copyright 2016, Optimizely and contributors
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
module OptimizelyBenchmark
  TEST_DATA = {
    'test_activate' => {
      10 => 'test',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_activate_with_attributes' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'test'
    },
    'test_activate_with_forced_variation' => {
      10 => 'variation_user',
      25 => 'variation_user',
      50 => 'variation_user'
    },
    'test_activate_grouped_exp' => {
      10 => 'no',
      25 => 'test',
      50 => 'optimizely_user'
    },
    'test_activate_grouped_exp_with_attributes' => {
      10 => 'test',
      25 => 'yes',
      50 => 'test'
    },
    'test_get_variation' => {
      10 => 'test',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_get_variation_with_attributes' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'test'
    },
    'test_get_variation_with_forced_variation' => {
      10 => 'variation_user',
      25 => 'variation_user',
      50 => 'variation_user'
    },
    'test_get_variation_grouped_exp' => {
      10 => 'no',
      25 => 'test',
      50 => 'optimizely_user'
    },
    'test_get_variation_grouped_exp_with_attributes' => {
      10 => 'test',
      25 => 'yes',
      50 => 'test'
    },
    'test_track' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_with_attributes' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_with_revenue' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_with_attributes_and_revenue' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_grouped_exp' => {
      10 => 'no',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_grouped_exp_with_attributes' => {
      10 => 'optimizely_user',
      25 => 'yes',
      50 => 'test'
    },
    'test_track_grouped_exp_with_revenue' => {
      10 => 'no',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_grouped_exp_with_attributes_and_revenue' => {
      10 => 'optimizely_user',
      25 => 'yes',
      50 => 'test'
    },
  }
end
