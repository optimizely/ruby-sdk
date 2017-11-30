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

Rails.application.routes.draw do
  resources :demo, only: [:new, :create]
  post 'demo/buy', to: 'demo#buy', as: :buy
  get 'demo/config', to: 'demo#new'
  post 'demo/config', to: 'demo#create'
  delete 'demo/delete_messages', to: 'demo#delete_messages', as: :delete_messages
  get 'demo/messages', to: 'demo#log_messages', as: :messages
  get 'demo/shop', to: 'demo#shop', as: :shop
  get 'demo/visitors', to: 'demo#visitors', as: :visitors
  # root path
  root 'home#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
