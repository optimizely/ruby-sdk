require 'coveralls'
Coveralls.wear!
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'optimizely'
require 'spec_params'

require 'webmock/rspec'
