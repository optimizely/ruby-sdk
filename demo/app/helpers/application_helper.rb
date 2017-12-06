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

module ApplicationHelper
  def bootstrap_class_for(flash_type)
    case flash_type
    when 'success'
      'alert-success'   # Green
    when 'error'
      'alert-danger'    # Red
    when 'alert'
      'alert-warning'   # Yellow
    when 'notice'
      'alert-info'      # Blue
    else
      flash_type.to_s
    end
  end

  def assign_active_class(path)
    current_page?(path) ? 'active' : ''
  end

  def get_level_class(type)
    if type == LogMessage::LOGGER_LEVELS[:DEBUG] || type == LogMessage::LOGGER_LEVELS[:INFO]
      'table-info'
    elsif type == LogMessage::LOGGER_LEVELS[:WARN]
      'table-warning'
    elsif type == LogMessage::LOGGER_LEVELS[:ERROR] || type == LogMessage::LOGGER_LEVELS[:FATAL]
      'table-danger'
    else
      ''
    end
  end
  def generate_json_view(json)
    JSON.pretty_generate JSON.parse(json)
  end
end
