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

class Config < ActiveHash::Base
  @@data = []

  fields :project_id, :experiment_key, :event_key, :project_configuration_json

  URL = 'https://cdn.optimizely.com/json'.freeze

  def self.find_by_project_id(project_id)
    @@data.find { |config| config.project_id == project_id }
  end

  def self.find_or_create_by_project_id(project_id)
    @@data.find { |config| config.project_id == project_id } || (@@data << create(project_id: project_id)).last
  end

  def update(params)
    self.experiment_key = params[:experiment_key]
    self.event_key = params[:event_key]
    self.project_configuration_json = params[:project_configuration_json]
    save
  end
end
