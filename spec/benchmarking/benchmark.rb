# frozen_string_literal: true

#
#    Copyright 2016-2017, Optimizely and contributors
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
require 'optimizely'
require 'benchmark'
require_relative 'data.rb'

module OptimizelyBenchmark
  ITERATIONS = 10

  class PerformanceTests
    @error_handler = Optimizely::NoOpErrorHandler.new
    @logger = Optimizely::NoOpLogger.new

    def self.test_initialize(testdata, _optly, _user_id)
      Optimizely::Project.new(testdata)
    end

    def self.test_initialize_logger(testdata, _optly, _user_id)
      Optimizely::Project.new(testdata, nil, @logger)
    end

    def self.test_initialize_logger_and_error_handler(testdata, _optly, _user_id)
      Optimizely::Project.new(testdata, nil, @logger, @error_handler)
    end

    def self.test_initialize_no_schema_validation(testdata, _optly, _user_id)
      Optimizely::Project.new(testdata, nil, nil, nil, true)
    end

    def self.test_initialize_logger_no_schema_validation(testdata, _optly, _user_id)
      Optimizely::Project.new(testdata, nil, @logger, nil, true)
    end

    def self.test_initialize_error_handler_no_schema_validation(testdata, _optly, _user_id)
      Optimizely::Project.new(testdata, nil, nil, @error_handler, true)
    end

    def self.test_initialize_logger_error_handler_no_schema_validation(testdata, _optly, _user_id)
      Optimizely::Project.new(testdata, nil, @logger, @error_handler, true)
    end

    def self.test_activate(_testdata, optly, user_id)
      optly.activate('testExperiment2', user_id)
    end

    def self.test_activate_with_attributes(_testdata, optly, user_id)
      optly.activate('testExperimentWithFirefoxAudience', user_id, 'browser_type' => 'firefox')
    end

    def self.test_activate_with_forced_variation(_testdata, optly, user_id)
      optly.activate('testExperiment2', user_id)
    end

    def self.test_activate_grouped_exp(_testdata, optly, user_id)
      optly.activate('mutex_exp2', user_id)
    end

    def self.test_activate_grouped_exp_with_attributes(_testdata, optly, user_id)
      optly.activate('mutex_exp1', user_id, 'browser_type' => 'firefox')
    end

    def self.test_get_variation(_testdata, optly, user_id)
      optly.get_variation('testExperiment2', user_id)
    end

    def self.test_get_variation_with_attributes(_testdata, optly, user_id)
      optly.get_variation('testExperimentWithFirefoxAudience', user_id, 'browser_type' => 'firefox')
    end

    def self.test_get_variation_with_forced_variation(_testdata, optly, _user_id)
      optly.get_variation('testExperiment2', 'variation_user')
    end

    def self.test_get_variation_grouped_exp(_testdata, optly, user_id)
      optly.get_variation('mutex_exp2', user_id)
    end

    def self.test_get_variation_grouped_exp_with_attributes(_testdata, optly, user_id)
      optly.get_variation('mutex_exp1', user_id, 'browser_type' => 'firefox')
    end

    def self.test_track(_testdata, optly, user_id)
      optly.track('testEvent', user_id)
    end

    def self.test_track_with_attributes(_testdata, optly, user_id)
      optly.track('testEventWithAudiences', user_id, 'browser_type' => 'firefox')
    end

    def self.test_track_with_revenue(_testdata, optly, user_id)
      optly.track('testEvent', user_id, nil, 666)
    end

    def self.test_track_with_attributes_and_revenue(_testdata, optly, user_id)
      optly.track('testEventWithAudiences', user_id, {'browser_type' => 'firefox'}, 666)
    end

    def self.test_track_grouped_exp(_testdata, optly, user_id)
      optly.track('testEventWithMultipleGroupedExperiments', user_id)
    end

    def self.test_track_grouped_exp_with_attributes(_testdata, optly, user_id)
      optly.track('testEventWithMultipleExperiments', user_id, 'browser_type' => 'firefox')
    end

    def self.test_track_grouped_exp_with_revenue(_testdata, optly, user_id)
      optly.track('testEventWithMultipleGroupedExperiments', user_id, nil, 666)
    end

    def self.test_track_grouped_exp_with_attributes_and_revenue(_testdata, optly, user_id)
      optly.track('testEventWithMultipleExperiments', user_id, {'browser_type' => 'firefox'}, 666)
    end
  end

  module_function

  def run_tests
    testdata10 = File.read('spec/benchmarking/testdata_10.json')
    testdata25 = File.read('spec/benchmarking/testdata_25.json')
    testdata50 = File.read('spec/benchmarking/testdata_50.json')
    event_dispatcher = Optimizely::NoOpEventDispatcher.new
    optly10 = Optimizely::Project.new(testdata10, event_dispatcher)
    optly25 = Optimizely::Project.new(testdata25, event_dispatcher)
    optly50 = Optimizely::Project.new(testdata50, event_dispatcher)

    tests = PerformanceTests.methods(false)
    tests.each do |test|
      tms10 = []
      tms25 = []
      tms50 = []

      ITERATIONS.times do
        tms10.push(Benchmark
          .measure { PerformanceTests.send(test, testdata10, optly10, TEST_DATA.fetch(test, {}).fetch(10, '')) })
        tms25.push(Benchmark
          .measure { PerformanceTests.send(test, testdata25, optly25, TEST_DATA.fetch(test, {}).fetch(25, '')) })
        tms50.push(Benchmark
          .measure { PerformanceTests.send(test, testdata50, optly50, TEST_DATA.fetch(test, {}).fetch(50, '')) })
      end

      trim_max_min(tms10)
      trim_max_min(tms25)
      trim_max_min(tms50)

      puts test, '   ' + Benchmark::CAPTION
      puts '10 exp:' + ((tms10.reduce(:+) / tms10.size) * 1000).format(Benchmark::FORMAT)
      puts '25 exp:' + ((tms25.reduce(:+) / tms25.size) * 1000).format(Benchmark::FORMAT)
      puts '50 exp:' + ((tms50.reduce(:+) / tms50.size) * 1000).format(Benchmark::FORMAT)
      puts ''
    end
  end

  def trim_max_min(tms)
    tms.delete_at(tms.index(tms.min_by(&:real)))
    tms.delete_at(tms.index(tms.max_by(&:real)))
  end
end
