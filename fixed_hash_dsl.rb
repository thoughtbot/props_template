#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'
require 'json'

# Fixed hash-based DSL that properly handles arrays
class HashDSL
  def initialize
    @stack = []
    @current = {}
    @root = @current
  end
  
  def set!(key, value = nil)
    key = key.to_s
    
    if block_given?
      # For blocks, we need to capture what gets created inside
      @stack.push(@current)
      new_context = {}
      old_current = @current
      @current = new_context
      
      yield
      
      # Set the result on the parent
      old_current[key] = new_context
      @current = @stack.pop
    else
      @current[key] = value
    end
    
    nil
  end
  
  def array!(collection = nil, &block)
    if collection
      # For collections, build array of objects
      result = []
      collection.each do |item|
        @stack.push(@current)
        item_obj = {}
        @current = item_obj
        
        yield item
        
        result << item_obj
        @current = @stack.pop
      end
      return result  # This should be assigned by caller
    else
      # Manual array building - not implemented yet
      []
    end
  end
  
  def result!
    JSON.generate(@root)
  end
  
  # Debug method
  def inspect_hash
    @root
  end
end

# Need to fix the array assignment issue
class BetterHashDSL
  def initialize
    @stack = []
    @current = {}
    @root = @current
    @array_mode = false
  end
  
  def set!(key, value = nil)
    key = key.to_s
    
    if block_given?
      @stack.push([@current, @array_mode])
      
      # Check if we're about to build an array
      old_current = @current
      @current = {}  # New object context
      @array_mode = false
      
      result = yield
      
      # If yield returned an array, use that; otherwise use the object we built
      if result.is_a?(Array)
        old_current[key] = result
      else
        old_current[key] = @current
      end
      
      @current, @array_mode = @stack.pop
    else
      @current[key] = value
    end
    
    nil
  end
  
  def array!(collection = nil, &block)
    if collection
      result = []
      collection.each do |item|
        @stack.push([@current, @array_mode])
        item_obj = {}
        @current = item_obj
        @array_mode = false
        
        yield item
        
        result << item_obj
        @current, @array_mode = @stack.pop
      end
      return result  # This gets returned to set! block
    else
      []
    end
  end
  
  def result!
    JSON.generate(@root)
  end
  
  def inspect_hash
    @root
  end
end

# Test data
users = 5.times.map do |i|
  {
    id: i,
    name: "User #{i}",
    active: i.even?
  }
end

puts "Testing array handling fix:"

# Test the fixed version
json = BetterHashDSL.new
json.set!(:users) do
  json.array!(users) do |user|
    json.set!(:id, user[:id])
    json.set!(:name, user[:name])
  end
end
json.set!(:status, "success")

puts "Hash structure: #{json.inspect_hash}"
puts "JSON result: #{json.result!}"

# Compare with StringWriter
class TestStringWriter
  def initialize
    @stream = Oj::StringWriter.new(mode: :rails)
    @scope = nil
  end
  
  def set!(key, value = nil)
    if @scope.nil?
      @scope = :object
      @stream.push_object
    end
    
    if block_given?
      @stream.push_key(key.to_s)
      @scope = nil
      yield
      if @scope.nil?
        @stream.push_object
      end
      @stream.pop
    else
      @stream.push_value(value, key.to_s)
    end
    
    @scope = :object
    nil
  end
  
  def array!(collection = nil, &block)
    if @scope.nil?
      @scope = :array
      @stream.push_array
    end
    
    collection.each do |item|
      @scope = nil
      yield item
      if @scope.nil?
        @stream.push_object
      end
      @stream.pop
    end
    
    @scope = :array
    nil
  end
  
  def result!
    if @scope.nil?
      @stream.push_object
    end
    @stream.pop
    
    json = @stream.raw_json
    @stream.reset
    @scope = nil
    json
  end
end

sw = TestStringWriter.new
sw.set!(:users) do
  sw.array!(users) do |user|
    sw.set!(:id, user[:id])
    sw.set!(:name, user[:name])
  end
end
sw.set!(:status, "success")
sw_result = sw.result!

puts "\nComparison:"
puts "Hash DSL:     #{json.result!}"
puts "StringWriter: #{sw_result}"
puts "Equal? #{json.result! == sw_result}"

puts "\nPerformance comparison:"
Benchmark.bm(30) do |x|
  x.report("StringWriter DSL") do
    1000.times do
      sw = TestStringWriter.new
      sw.set!(:users) do
        sw.array!(users) do |user|
          sw.set!(:id, user[:id])
          sw.set!(:name, user[:name])
          sw.set!(:active, user[:active])
        end
      end
      sw.set!(:status, "success")
      result = sw.result!
    end
  end
  
  x.report("Hash DSL") do
    1000.times do
      json = BetterHashDSL.new
      json.set!(:users) do
        json.array!(users) do |user|
          json.set!(:id, user[:id])
          json.set!(:name, user[:name])
          json.set!(:active, user[:active])
        end
      end
      json.set!(:status, "success")
      result = json.result!
    end
  end
  
  x.report("Direct hash") do
    1000.times do
      hash = {
        users: users.map { |u| { id: u[:id], name: u[:name], active: u[:active] } },
        status: "success"
      }
      result = JSON.generate(hash)
    end
  end
end