#
#    Copyright 2017, Optimizely and contributors
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

class LogMessage < ActiveHash::Base
  @@data = []

  fields :type, :message
  field  :created_at, default: Time.now

  LOGGER_LEVELS = {DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3, FATAL: 4, UNKNOWN: 5}.freeze

  def self.create_record(type, message)
    @@data << create(type: type, message: message, created_at: Time.now)
  end

  def self.all_logs
    @@data.reverse
  end

  def self.delete_all_logs
    delete_all
    @@data = []
  end
end
