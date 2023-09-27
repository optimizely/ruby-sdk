# frozen_string_literal: true

require_relative 'lib/optimizely/version'

Gem::Specification.new do |spec|
  spec.name          = 'optimizely-sdk'
  spec.version       = Optimizely::VERSION
  spec.authors       = ['Optimizely']
  spec.email         = ['developers@optimizely.com']
  spec.required_ruby_version = '>= 2.7'

  spec.summary       = "Ruby SDK for Optimizely's testing framework"
  spec.description   = 'A Ruby SDK for use with Optimizely Feature Experimentation, Optimizely Full Stack (legacy), and Optimizely Rollouts'
  spec.homepage      = 'https://www.optimizely.com/'
  spec.license       = 'Apache-2.0'

  spec.files         = Dir['lib/**/*', 'LICENSE']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'coveralls_reborn'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'webmock'

  spec.add_runtime_dependency 'json-schema', '~> 2.6'
  spec.add_runtime_dependency 'murmurhash3', '~> 0.1'
end
