# frozen_string_literal: true

#
#    Copyright 2019, Optimizely and contributors
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
require 'optimizely/config_manager/async_scheduler'
require 'optimizely/logger'

describe Optimizely::AsyncScheduler do
  it 'should log error trace when callback fails to execute' do
    def some_callback(_args); end

    spy_logger = spy('logger')

    scheduler = Optimizely::AsyncScheduler.new(method(:some_callback), 10, false, spy_logger)
    scheduler.start!

    while scheduler.running; end
    expect(spy_logger).to have_received(:log).with(
      Logger::ERROR,
      'Something went wrong when executing passed callback. wrong number of arguments (given 0, expected 1)'
    )
  end
end
