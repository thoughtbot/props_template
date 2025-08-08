#!/usr/bin/env ruby

require 'json'

# Simplified approach - treat everything as hashes, convert arrays at the end
class CacheableHashDSL
  def initialize
    @root = {}
    @stack = []
    @current = @root
    @array_paths = Set.new  # Track which paths should be arrays
  end
  
  def set!(key, value = nil, options = {})
    key = key.to_s
    current_path = build_path + [key]
    
    # Check cache first
    if options[:cache]
      cached_data = read_cache(options[:cache])
      if cached_data
        @current[key] = cached_data
        return nil
      end
    end
    
    if block_given?
      @stack.push([@current, build_path])
      @current[key] = {}
      old_current = @current
      @current = @current[key]
      
      result = yield
      
      # Mark as array if needed
      if result == :array_marker
        @array_paths.add(current_path.join('.'))
      end
      
      # Cache the result
      if options[:cache]
        write_cache(options[:cache], old_current[key])
      end
      
      @current, _ = @stack.pop
    else
      @current[key] = value
    end
    
    nil
  end
  
  def array!(collection = nil)
    if collection
      collection.each_with_index do |item, index|
        @stack.push([@current, build_path])
        @current[index.to_s] = {}
        @current = @current[index.to_s]
        
        yield item
        
        @current, _ = @stack.pop
      end
    end
    
    :array_marker
  end
  
  def result!
    final_data = convert_to_final_format(@root, "")
    JSON.generate(final_data)
  end
  
  private
  
  def build_path
    # Simple path building - would need to be more sophisticated
    []
  end
  
  def read_cache(key)
    @cache ||= {}
    @cache[key]
  end
  
  def write_cache(key, value)
    @cache ||= {}
    @cache[key] = value.dup  # Deep copy to avoid mutations
  end
  
  def convert_to_final_format(obj, path)
    return obj unless obj.is_a?(Hash)
    
    # Check if this should be an array (has numeric string keys in order)
    if should_be_array?(obj)
      # Convert to array
      keys = obj.keys.sort_by(&:to_i)
      keys.map { |key| convert_to_final_format(obj[key], "#{path}.#{key}") }
    else
      # Regular object
      result = {}
      obj.each do |key, value|
        result[key] = convert_to_final_format(value, "#{path}.#{key}")
      end
      result
    end
  end
  
  def should_be_array?(hash)
    return false unless hash.is_a?(Hash)
    return false if hash.empty?
    
    keys = hash.keys
    # Check if all keys are numeric strings starting from 0
    numeric_keys = keys.select { |k| k.match?(/^\d+$/) }.sort_by(&:to_i)
    return false if numeric_keys.length != keys.length
    
    # Check if they form a sequence 0, 1, 2, ...
    numeric_keys == (0...numeric_keys.length).map(&:to_s)
  end
end

# Test it
puts "=== Testing Cacheable Hash DSL ==="

users = [
  { id: 1, name: "Alice", email: "alice@example.com" },
  { id: 2, name: "Bob", email: "bob@example.com" }
]

# First render - populate cache
puts "First render (populating cache):"
dsl1 = CacheableHashDSL.new

dsl1.set!(:response) do
  dsl1.set!(:users, cache: "users_cache") do
    dsl1.array!(users) do |user|
      dsl1.set!(:id, user[:id])
      dsl1.set!(:name, user[:name])
      dsl1.set!(:email, user[:email])
    end
  end
  
  dsl1.set!(:metadata) do
    dsl1.set!(:count, users.length)
    dsl1.set!(:generated_at, "2023-12-07")
  end
end

result1 = dsl1.result!
puts result1

# Check what got cached
cached_users = dsl1.send(:read_cache, "users_cache")
puts "\nCached users data:"
puts cached_users.inspect

# Second render - use cache
puts "\nSecond render (using cache):"
dsl2 = CacheableHashDSL.new

# Simulate cache by copying it over
dsl2.instance_variable_set(:@cache, dsl1.instance_variable_get(:@cache))

dsl2.set!(:response) do
  dsl2.set!(:users, cache: "users_cache") do
    # This should not execute because of cache hit
    raise "Cache miss! This shouldn't happen"
  end
  
  dsl2.set!(:metadata) do
    dsl2.set!(:count, 999)  # Different data
    dsl2.set!(:generated_at, "2023-12-08")  # Different timestamp
  end
end

result2 = dsl2.result!
puts result2

puts "\nAre results equivalent for cached part? #{result1.include?('"users":[{"id":1') && result2.include?('"users":[{"id":1')}"

# Test performance implications
require 'benchmark'

puts "\nPerformance test:"
Benchmark.bm(20) do |x|
  x.report("No cache") do
    1000.times do
      dsl = CacheableHashDSL.new
      dsl.set!(:users) do
        dsl.array!(users) do |user|
          dsl.set!(:id, user[:id])
          dsl.set!(:name, user[:name])
          dsl.set!(:email, user[:email])
        end
      end
      result = dsl.result!
    end
  end
  
  x.report("With cache") do
    # Pre-populate cache
    cache_dsl = CacheableHashDSL.new
    cache_dsl.set!(:users, cache: "perf_test") do
      cache_dsl.array!(users) do |user|
        cache_dsl.set!(:id, user[:id])
        cache_dsl.set!(:name, user[:name])
        cache_dsl.set!(:email, user[:email])
      end
    end
    cache_dsl.result!
    
    cached_data = cache_dsl.instance_variable_get(:@cache)
    
    1000.times do
      dsl = CacheableHashDSL.new
      dsl.instance_variable_set(:@cache, cached_data)
      dsl.set!(:users, cache: "perf_test") do
        # Should not execute
        raise "Cache miss"
      end
      result = dsl.result!
    end
  end
end