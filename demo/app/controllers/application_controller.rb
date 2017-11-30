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

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def optimizely_client_present?
    redirect_to demo_config_path unless OptimizelyService.optimizely_client_present?
  end

  def get_visitor
    visitor = Visitor.find(params[:id].to_i)
    @visitor = visitor.present? ? visitor : Visitor::VISITORS.first
  end
end
