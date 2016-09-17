require './optimizely'
require 'benchmark'

class PerformanceTests
  @error_handler = Optimizely::NoOpErrorHandler.new
  @logger = Optimizely::NoOpLogger.new

  def self.test_initialize(testdata, optly)
    Optimizely::Project.new(testdata)
  end

  def self.test_initialize_logger(testdata, optly)
    Optimizely::Project.new(testdata, nil, @logger)
  end

  def self.test_initialize_logger_and_error_handler(testdata, optly)
    Optimizely::Project.new(testdata, nil, @logger, @error_handler)
  end

  def self.test_initialize_no_schema_validation(testdata, optly)
    Optimizely::Project.new(testdata, nil, nil, nil, true)
  end

  def self.test_initialize_logger_no_schema_validation(testdata, optly)
    Optimizely::Project.new(testdata, nil, @logger, nil, true)
  end

  def self.test_initialize_error_handler_no_schema_validation(testdata, optly)
    Optimizely::Project.new(testdata, nil, nil, @error_handler, true)
  end

  def self.test_initialize_logger_error_handler_no_schema_validation(testdata, optly)
    Optimizely::Project.new(testdata, nil, @logger, @error_handler, true)
  end

  def self.test_initialize_error_handler_no_schema_validation(testdata, optly)
    Optimizely::Project.new(testdata, nil, nil, @error_handler, true)
  end

  def self.test_activate(testdata, optly)
    optly.activate('testExperiment2', 'optimizely_user')
  end

  def self.test_activate_with_attributes(testdata, optly)
    optly.activate('testExperimentWithFirefoxAudience', 'optimizely_user', {'browser_type' => 'firefox'})
  end

  def self.test_activate_with_forced_variation(testdata, optly)
    optly.activate('testExperiment2', 'variation_user')
  end

  def self.test_activate_grouped_exp(testdata, optly)
    optly.activate('mutex_exp2', 'optimizely_user')
  end

  def self.test_activate_grouped_exp_with_attributes(testdata, optly)
    optly.activate('mutex_exp1', 'optimizely_user', {'browser_type' => 'firefox'})
  end

  def self.test_get_variation(testdata, optly)
    optly.get_variation('testExperiment2', 'optimizely_user')
  end

  def self.test_get_variation_with_attributes(testdata, optly)
    optly.get_variation('testExperimentWithFirefoxAudience', 'optimizely_user', {'browser_type' => 'firefox'})
  end

  def self.test_get_variation_with_forced_variation(testdata, optly)
    optly.get_variation('testExperiment2', 'variation_user')
  end

  def self.test_get_variation_grouped_exp(testdata, optly)
    optly.get_variation('mutex_exp2', 'optimizely_user')
  end

  def self.test_get_variation_grouped_exp_with_attributes(testdata, optly)
    optly.get_variation('mutex_exp1', 'optimizely_user')
  end

  def self.test_track(testdata, optly)
    optly.track('testEvent', 'optimizely_user')
  end

  def self.test_track_with_attributes(testdata, optly)
    optly.track('testEventWithAudiences' 'optimizely_user', {'browser_type' => 'firefox'})
  end

  def self.test_track_with_revenue(testdata, optly)
    optly.track('testEvent', 'optimizely_user', nil, 666)
  end

  def self.test_track_with_attributes_and_revenue(testdata, optly)
    optly.track('testEventWithAudiences', 'optimizely_user', {'browser_type' => 'firefox'}, 666)
  end

  def self.test_track_grouped_exp(testdata, optly)
    optly.track('testEventWithMultipleGroupedExperiments', 'optimizely_user')
  end

  def self.test_track_grouped_exp_with_attributes(testdata, optly)
    optly.track('testEventWithMultipleExperiments', 'optimizely_user', {'browser_type' => 'firefox'})
  end

  def self.test_track_grouped_exp_with_revenue(testdata, optly)
    optly.track('testEventWithMultipleGroupedExperiments', 'optimizely_user', nil, 666)
  end

  def self.test_track_grouped_exp_with_attributes_and_revenue(testdata, optly)
    optly.track('testEventWithMultipleExperiments', 'optimizely_user', {'browser_type' => 'firefox'}, 666)
  end
end

def run_tests
  testdata10 = File.read('testdata_10.json')
  testdata25 = File.read('testdata_25.json')
  testdata50 = File.read('testdata_50.json')
  optly10 = Optimizely::Project.new(testdata10)
  optly25 = Optimizely::Project.new(testdata25)
  optly50 = Optimizely::Project.new(testdata50)

  tests = PerformanceTests.methods(false)
  tests.each do |test|
    puts '', test
    Benchmark.bmbm do |x|
      x.report('10 exps') { PerformanceTests.send(test, testdata10, optly10) }
      x.report('25 exps') { PerformanceTests.send(test, testdata25, optly25) }
      x.report('50 exps') { PerformanceTests.send(test, testdata50, optly50) }
    end
  end
end
