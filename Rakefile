# frozen_string_literal: true

require 'bundler/gem_tasks'
require_relative 'spec/benchmarking/benchmark'

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError # rubocop:disable Lint/HandleExceptions, Lint/RedundantCopDisableDirective, List/UnneededCopDisableDirective
end
require 'optimizely/version'

Bundler::GemHelper.install_tasks

task :benchmark do
  OptimizelyBenchmark.run_tests
end

task default: :spec
