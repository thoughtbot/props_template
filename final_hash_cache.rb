#!/usr/bin/env ruby

require 'json'
require 'benchmark'

# Working hash-based caching DSL
class HashCacheDSL
  def initialize
    @root = {}
    @stack = []
    @current = @root
    @cache = {}
  end
  
  def set!(key, value = nil, options = {})
    key = key.to_s
    puts "  -> set!(#{key}, options: #{options.inspect})"
    
    # Check cache FIRST - before any block execution
    if options[:cache] && @cache.key?(options[:cache])
      puts "  -> Cache HIT for #{options[:cache]}"
      @current[key] = @cache[options[:cache]]
      return nil
    end
    
    if block_given?
      puts "  -> Block given for #{key}"
      # Set up new context for the block
      @stack.push(@current)
      @current[key] = {}
      block_context = @current[key] 
      @current = block_context
      
      # Execute block
      result = yield
      
      # Cache the result AFTER block execution
      if options[:cache]
        puts "  -> Caching result for #{options[:cache]}: #{block_context.inspect[0..100]}..."
        @cache[options[:cache]] = block_context.dup
      else
        puts "  -> No cache option for #{key}"
      end
      
      # Restore context
      @current = @stack.pop
    else
      @current[key] = value
    end
    
    nil
  end
  
  def array!(collection = nil)
    return :array_marker unless collection
    
    collection.each_with_index do |item, index|
      @stack.push(@current)
      @current[index.to_s] = {}
      @current = @current[index.to_s]
      
      yield item
      
      @current = @stack.pop
    end
    
    :array_marker
  end
  
  def result!
    JSON.generate(convert_arrays(@root))
  end
  
  def cache_stats
    @cache
  end
  
  def copy_cache_from(other_dsl)
    @cache = other_dsl.cache_stats.dup
  end
  
  private
  
  def convert_arrays(obj)
    return obj unless obj.is_a?(Hash)
    
    if is_array_hash?(obj)
      # Convert to array
      keys = obj.keys.sort_by(&:to_i)
      keys.map { |key| convert_arrays(obj[key]) }
    else
      # Regular object - recursively process
      result = {}
      obj.each { |k, v| result[k] = convert_arrays(v) }
      result
    end
  end
  
  def is_array_hash?(hash)
    return false unless hash.is_a?(Hash)
    return false if hash.empty?
    
    keys = hash.keys
    numeric_keys = keys.select { |k| k.match?(/^\d+$/) }
    return false unless numeric_keys.length == keys.length
    
    sorted_keys = numeric_keys.sort_by(&:to_i)
    sorted_keys == (0...sorted_keys.length).map(&:to_s)
  end
end

# Test the corrected implementation
puts "=== Hash-Based Caching Test ==="

users = [
  { id: 1, name: "Alice", email: "alice@example.com" },
  { id: 2, name: "Bob", email: "bob@example.com" },
  { id: 3, name: "Charlie", email: "charlie@example.com" }
]

# First render - populate cache
puts "1. First render (should populate cache):"
dsl1 = HashCacheDSL.new

dsl1.set!(:api_response) do
  puts "  -> Inside api_response block"
  dsl1.set!(:users, nil, cache: "users_v1") do
    puts "  -> Building users from scratch"
    dsl1.array!(users) do |user|
      dsl1.set!(:id, user[:id])
      dsl1.set!(:name, user[:name])
      dsl1.set!(:email, user[:email])
    end
  end
  
  dsl1.set!(:metadata) do
    dsl1.set!(:total, users.length)
    dsl1.set!(:generated_at, Time.now.to_s)
  end
end

result1 = dsl1.result!
puts result1

puts "\n2. Cache contents after first render:"
puts dsl1.cache_stats.inspect

# Second render - should use cache
puts "\n3. Second render (should use cache):"
dsl2 = HashCacheDSL.new
dsl2.copy_cache_from(dsl1)  # Copy cache

dsl2.set!(:api_response) do
  dsl2.set!(:users, nil, cache: "users_v1") do
    puts "  -> This should NOT print (cache hit)"
    raise "Cache miss!"
  end
  
  dsl2.set!(:metadata) do
    dsl2.set!(:total, 999)  # Different data
    dsl2.set!(:generated_at, "CACHED_VERSION")
  end
end

result2 = dsl2.result!
puts result2

puts "\n4. Verification:"
puts "Both results have same users? #{result1.include?('Alice') && result2.include?('Alice')}"
puts "Different metadata? #{result1.include?('CACHED_VERSION') != result2.include?('CACHED_VERSION')}"

# Performance comparison
puts "\n5. Performance Comparison:"
Benchmark.bm(15) do |x|
  x.report("No cache") do
    1000.times do
      dsl = HashCacheDSL.new
      dsl.set!(:users) do
        dsl.array!(users) do |user|
          dsl.set!(:id, user[:id])
          dsl.set!(:name, user[:name])
          dsl.set!(:email, user[:email])
        end
      end
      dsl.result!
    end
  end
  
  x.report("With cache") do
    # Pre-warm cache
    cache_dsl = HashCacheDSL.new
    cache_dsl.set!(:users, cache: "benchmark_users") do
      cache_dsl.array!(users) do |user|
        cache_dsl.set!(:id, user[:id])
        cache_dsl.set!(:name, user[:name])
        cache_dsl.set!(:email, user[:email])
      end
    end
    cache_dsl.result!
    
    1000.times do
      dsl = HashCacheDSL.new
      dsl.copy_cache_from(cache_dsl)
      dsl.set!(:users, cache: "benchmark_users") do
        # This won't execute
      end
      dsl.result!
    end
  end
end

# Compare with direct hash approach
puts "\n6. Compare with Direct Hash (no DSL):"
Benchmark.bm(15) do |x|
  x.report("Hash DSL") do
    1000.times do
      dsl = HashCacheDSL.new
      dsl.set!(:users) do
        dsl.array!(users) do |user|
          dsl.set!(:id, user[:id])
          dsl.set!(:name, user[:name])
          dsl.set!(:email, user[:email])
        end
      end
      dsl.result!
    end
  end
  
  x.report("Direct hash") do
    1000.times do
      result = {
        users: users.map { |u| { id: u[:id], name: u[:name], email: u[:email] } }
      }
      JSON.generate(result)
    end
  end
end