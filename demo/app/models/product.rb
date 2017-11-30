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

class Product
  Event_Tags = {
    int_param: 4242,
    string_param: "4242",
    bool_param: true,
    revenue: 1337,
    value: 100
  }.freeze
  
  PRODUCTS = [
    {
      id: 1,
      name: 'Long Sleeve Shirt',
      color: 'Baby Blue',
      category: 'Shirts',
      price: 54,
      image_url: 'item_1.png'
    },
    {
      id: 2,
      name: 'Bo Henry',
      color: 'Khaki',
      category: 'Shorts',
      price: 37,
      image_url: 'item_2.png'
    },
    {
      id: 3,
      name: 'The "Go" Bag',
      color: 'Forest Green',
      category: 'Bags',
      price: 118,
      image_url: 'item_3.png'
    },
    {
      id: 4,
      name: 'Springtime',
      color: 'Rose',
      category: 'Dresses',
      price: 84,
      image_url: 'item_4.png'
    },
    {
      id: 5,
      name: 'The Night Out',
      color: 'Olive Green',
      category: 'Dresses',
      price: 153,
      image_url: 'item_5.png'
    },
    {
      id: 6,
      name: 'Dawson Trolley',
      color: 'Pine Green',
      category: 'Shirts',
      price: 107,
      image_url: 'item_6.png'
    }
  ].freeze

  def self.find(id)
    PRODUCTS.find { |product| product[:id] == id }
  end
  
end
