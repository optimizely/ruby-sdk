# frozen_string_literal: true

#
#    Copyright 2022-2025, Optimizely and contributors
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
require 'optimizely/odp/lru_cache'

describe Optimizely::LRUCache do
  it 'should create a cache with min config' do
    cache = Optimizely::LRUCache.new(1000, 2000)
    expect(cache.capacity).to eq 1000
    expect(cache.timeout).to eq 2000

    cache = Optimizely::LRUCache.new(0, 0)
    expect(cache.capacity).to eq 0
    expect(cache.timeout).to eq 0
  end

  it 'should save and lookup correctly' do
    max_size = 2
    cache = Optimizely::LRUCache.new(max_size, 1000)

    expect(cache.peek(1)).to be_nil
    cache.save(1, 100)                       # [1]
    cache.save(2, 200)                       # [1, 2]
    cache.save(3, 300)                       # [2, 3]
    expect(cache.peek(1)).to be_nil
    expect(cache.peek(2)).to be 200
    expect(cache.peek(3)).to be 300

    cache.save(2, 201)                       # [3, 2]
    cache.save(1, 101)                       # [2, 1]
    expect(cache.peek(1)).to eq 101
    expect(cache.peek(2)).to eq 201
    expect(cache.peek(3)).to be_nil

    expect(cache.lookup(3)).to be_nil        # [2, 1]
    expect(cache.lookup(2)).to eq 201        # [1, 2]
    cache.save(3, 302)                       # [2, 3]
    expect(cache.peek(1)).to be_nil
    expect(cache.peek(2)).to eq 201
    expect(cache.peek(3)).to eq 302

    expect(cache.lookup(3)).to eq 302        # [2, 3]
    cache.save(1, 103)                       # [3, 1]
    expect(cache.peek(1)).to eq 103
    expect(cache.peek(2)).to be_nil
    expect(cache.peek(3)).to eq 302

    expect(cache.instance_variable_get('@map').size).to be max_size
    expect(cache.instance_variable_get('@map').size).to be cache.capacity
  end

  it 'should disable cache with size zero' do
    cache = Optimizely::LRUCache.new(0, 1000)

    expect(cache.lookup(1)).to be_nil
    cache.save(1, 100)                       # [1]
    expect(cache.lookup(1)).to be_nil
  end

  it 'should disable with cache size less than zero' do
    cache = Optimizely::LRUCache.new(-2, 1000)

    expect(cache.lookup(1)).to be_nil
    cache.save(1, 100)                       # [1]
    expect(cache.lookup(1)).to be_nil
  end

  it 'should make elements stale after timeout' do
    max_timeout = 0.5

    cache = Optimizely::LRUCache.new(1000, max_timeout)

    cache.save(1, 100)                       # [1]
    cache.save(2, 200)                       # [1, 2]
    cache.save(3, 300)                       # [1, 2, 3]
    sleep(1.1) # wait to expire
    cache.save(4, 400)                       # [1, 2, 3, 4]
    cache.save(1, 101)                       # [2, 3, 4, 1]

    expect(cache.lookup(1)).to eq 101        # [4, 1]
    expect(cache.lookup(2)).to be_nil
    expect(cache.lookup(3)).to be_nil
    expect(cache.lookup(4)).to eq 400
  end

  it 'should make element stale after timeout even with lookup' do
    max_timeout = 1

    cache = Optimizely::LRUCache.new(1000, max_timeout)

    cache.save(1, 100)
    sleep(0.5)
    cache.lookup(1)
    sleep(0.5)
    expect(cache.lookup(1)).to be_nil
  end

  it 'should not make elements stale when timeout is zero' do
    max_timeout = 0
    cache = Optimizely::LRUCache.new(1000, max_timeout)

    cache.save(1, 100)                       # [1]
    cache.save(2, 200)                       # [1, 2]
    sleep(1) # wait to expire

    expect(cache.lookup(1)).to eq 100
    expect(cache.lookup(2)).to eq 200
  end

  it 'should not expire when timeout is less than zero' do
    max_timeout = -2
    cache = Optimizely::LRUCache.new(1000, max_timeout)

    cache.save(1, 100)                       # [1]
    cache.save(2, 200)                       # [1, 2]
    sleep(1) # wait to expire

    expect(cache.lookup(1)).to eq 100
    expect(cache.lookup(2)).to eq 200
  end

  it 'should clear cache when reset is called' do
    cache = Optimizely::LRUCache.new(1000, 600)
    cache.save('wow', 'great')
    cache.save('tow', 'freight')

    expect(cache.lookup('wow')).to eq 'great'
    expect(cache.instance_variable_get('@map').size).to eq 2

    cache.reset

    expect(cache.lookup('wow')).to be_nil
    expect(cache.instance_variable_get('@map').size).to eq 0

    cache.save('cow', 'crate')
    expect(cache.lookup('cow')).to eq 'crate'
  end

  it 'should remove existing key' do
    cache = Optimizely::LRUCache.new(3, 1000)

    cache.save('1', 100)
    cache.save('2', 200)
    cache.save('3', 300)

    expect(cache.lookup('1')).to eq 100
    expect(cache.lookup('2')).to eq 200
    expect(cache.lookup('3')).to eq 300

    cache.remove('2')

    expect(cache.lookup('1')).to eq 100
    expect(cache.lookup('2')).to be_nil
    expect(cache.lookup('3')).to eq 300
  end

  it 'should handle removing non-existent key' do
    cache = Optimizely::LRUCache.new(3, 1000)
    cache.save('1', 100)
    cache.save('2', 200)

    cache.remove('3') # Doesn't exist

    expect(cache.lookup('1')).to eq 100
    expect(cache.lookup('2')).to eq 200
  end

  it 'should handle removing from zero sized cache' do
    cache = Optimizely::LRUCache.new(0, 1000)
    cache.save('1', 100)
    cache.remove('1')

    expect(cache.lookup('1')).to be_nil
  end

  it 'should handle removing and adding back a key' do
    cache = Optimizely::LRUCache.new(3, 1000)
    cache.save('1', 100)
    cache.save('2', 200)
    cache.save('3', 300)

    cache.remove('2')
    cache.save('2', 201)

    expect(cache.lookup('1')).to eq 100
    expect(cache.lookup('2')).to eq 201
    expect(cache.lookup('3')).to eq 300
  end

  it 'should handle thread safety' do
    max_size = 100
    cache = Optimizely::LRUCache.new(max_size, 1000)

    (1..max_size).each do |i|
      cache.save(i.to_s, i * 100)
    end

    threads = []
    (1..(max_size / 2)).each do |i|
      thread = Thread.new do
        cache.remove(i.to_s)
      end
      threads << thread
    end

    threads.each(&:join)

    (1..max_size).each do |i|
      if i <= max_size / 2
        expect(cache.lookup(i.to_s)).to be_nil
      else
        expect(cache.lookup(i.to_s)).to eq(i * 100)
      end
    end

    expect(cache.instance_variable_get('@map').size).to eq(max_size / 2)
  end
end
