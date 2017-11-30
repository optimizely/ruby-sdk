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

class Visitor
  VISITORS = [
    {id: 10_001, name: 'Mike', age: 23},
    {id: 10_002, name: 'Ali', age: 29},
    {id: 10_003, name: 'Sally', age: 18},
    {id: 10_004, name: 'Jennifer', age: 44},
    {id: 10_005, name: 'Randall', age: 29}
  ].freeze

  def self.find(id)
    VISITORS.find { |visitor| visitor[:id] == id }
  end
end
