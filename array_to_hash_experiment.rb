#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'json'

# Convert array to hash with numeric keys
def array_to_hash(array)
  hash = {}
  array.each_with_index do |item, index|
    hash[index.to_s] = item
  end
  hash
end

# Convert hash back to array (preserve order)
def hash_to_array(hash)
  # Sort by numeric key to preserve order
  hash.keys.sort_by(&:to_i).map { |key| hash[key] }
end

# Test the conversion
users_array = [
  { id: 1, name: "Alice" },
  { id: 2, name: "Bob" },
  { id: 3, name: "Charlie" }
]

puts "Original array:"
puts users_array.inspect

# Convert to hash
users_hash = array_to_hash(users_array)
puts "\nAs hash:"
puts users_hash.inspect

# Convert back to array
restored_array = hash_to_array(users_hash)
puts "\nRestored array:"
puts restored_array.inspect

puts "\nAre they equal? #{users_array == restored_array}"

# Test JSON serialization
original_json = JSON.generate(users_array)
hash_json = JSON.generate(users_hash)
restored_json = JSON.generate(restored_array)

puts "\nJSON comparison:"
puts "Original:  #{original_json}"
puts "Hash:      #{hash_json}"
puts "Restored:  #{restored_json}"

# But we can reconstruct the array format in JSON
def hash_to_array_json(hash)
  sorted_values = hash.keys.sort_by(&:to_i).map { |key| hash[key] }
  JSON.generate(sorted_values)
end

reconstructed_json = hash_to_array_json(users_hash)
puts "Reconstructed: #{reconstructed_json}"
puts "JSON equal? #{original_json == reconstructed_json}"

# Now let's test caching with this approach
class HashArrayDSL
  def initialize
    @root = {}
    @stack = []
    @current = @root
    @array_markers = {}  # Track which keys should be arrays
  end
  
  def set!(key, value = nil, options = {})
    key = key.to_s
    
    if options[:cache] && (cached_data = Rails.cache.read(options[:cache]))
      # Cached data is already a hash, just merge it
      @current[key] = cached_data
      return
    end
    
    if block_given?
      @stack.push(@current)
      old_current = @current
      @current = {}
      
      result = yield
      
      if result == :array_marker
        @array_markers[generate_path(old_current, key)] = true
      end
      
      old_current[key] = @current
      
      # Cache the result if requested
      if options[:cache]
        Rails.cache.write(options[:cache], @current)
      end
      
      @current = @stack.pop
    else
      @current[key] = value
    end
    
    nil
  end
  
  def array!(collection = nil, &block)
    if collection
      collection.each_with_index do |item, index|
        @stack.push(@current)
        item_obj = {}
        @current = item_obj
        
        yield item
        
        @current = @stack.pop
        @current[index.to_s] = item_obj  # Use string index as key
      end
    end
    
    :array_marker
  end
  
  def result!
    JSON.generate(convert_hash_arrays_to_json(@root, @array_markers, ""))
  end
  
  private
  
  def generate_path(parent, key)
    # This is simplified - would need proper path tracking
    key
  end
  
  def convert_hash_arrays_to_json(obj, markers, path)
    if obj.is_a?(Hash)
      if markers[path] || has_numeric_keys(obj)
        # Convert hash with numeric keys back to array
        sorted_items = obj.keys.sort_by(&:to_i).map do |key|
          item_path = "#{path}.#{key}"
          convert_hash_arrays_to_json(obj[key], markers, item_path)
        end
        return sorted_items
      else
        # Regular object
        result = {}
        obj.each do |key, value|
          item_path = "#{path}.#{key}"
          result[key] = convert_hash_arrays_to_json(value, markers, item_path)
        end
        return result
      end
    else
      obj
    end
  end
  
  def has_numeric_keys(hash)
    return false unless hash.is_a?(Hash)
    return false if hash.empty?
    
    # Check if all keys are numeric strings in sequence
    keys = hash.keys.sort_by(&:to_i)
    keys == (0...keys.length).map(&:to_s)
  end
end

# Test this approach
puts "\n=== Testing Hash-Array DSL ==="

# Mock Rails.cache for testing
module Rails
  class << self
    def cache
      @cache ||= MockCache.new
    end
  end
  
  class MockCache
    def initialize
      @data = {}
    end
    
    def read(key)
      @data[key]
    end
    
    def write(key, value)
      @data[key] = value
    end
    
    def clear
      @data.clear
    end
  end
end

Rails.cache.clear

# Test the DSL
dsl = HashArrayDSL.new
dsl.set!(:users) do
  dsl.array!(users_array) do |user|
    dsl.set!(:id, user[:id])
    dsl.set!(:name, user[:name])
  end
end
dsl.set!(:status, "success")

result = dsl.result!
puts "DSL Result: #{result}"

# Test with caching
Rails.cache.clear
dsl2 = HashArrayDSL.new

# First render - should cache
dsl2.set!(:users, cache: "users_key") do  
  dsl2.array!(users_array) do |user|
    dsl2.set!(:id, user[:id])
    dsl2.set!(:name, user[:name])
  end
end

puts "Cached data: #{Rails.cache.read('users_key')}"

# Second render - should use cache  
dsl3 = HashArrayDSL.new
dsl3.set!(:users, cache: "users_key") do
  # This block shouldn't execute
  raise "Cache miss!"
end
dsl3.set!(:status, "from_cache")

cached_result = dsl3.result!
puts "Cached Result: #{cached_result}"