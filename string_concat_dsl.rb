#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'
require 'json'

# String concatenation DSL that mimics props_template API
class StringConcatDSL
  def initialize
    @json = +""
    @stack = []
    @first_key = true
    @in_array = false
    @first_array_item = true
  end
  
  def set!(key, value = nil)
    key = key.to_s
    
    if block_given?
      # Add comma if not first key in object
      @json << "," unless @first_key
      @first_key = false
      
      @json << "\"#{escape_key(key)}\":"
      
      # Save current state and start new object context
      @stack.push([@first_key, @in_array, @first_array_item])
      @first_key = true
      @in_array = false
      
      # Determine if we're starting an object or array
      start_pos = @json.length
      @json << "{"  # Assume object, we'll fix if it's array
      
      result = yield
      
      # If yield returned an array marker, fix the opening
      if result == :array_marker
        # Replace the { with [
        @json[start_pos] = "["
        @json << "]"
      else
        @json << "}"
      end
      
      # Restore state
      @first_key, @in_array, @first_array_item = @stack.pop
    else
      # Simple key-value pair
      @json << "," unless @first_key
      @first_key = false
      @json << "\"#{escape_key(key)}\":#{serialize_value(value)}"
    end
    
    nil
  end
  
  def array!(collection = nil, &block)
    # Mark that we're building an array
    @json[-1] = "["  # Replace the { that was just added
    
    if collection
      @first_array_item = true
      
      collection.each do |item|
        @json << "," unless @first_array_item
        @first_array_item = false
        
        # Save state for array item object
        @stack.push([@first_key, @in_array, @first_array_item])
        @first_key = true
        @in_array = true
        @first_array_item = true
        
        @json << "{"
        yield item
        @json << "}"
        
        # Restore state
        @first_key, @in_array, @first_array_item = @stack.pop
      end
    end
    
    :array_marker  # Signal that this created an array
  end
  
  def result!
    # Ensure we have a complete JSON object
    if @json.empty?
      @json << "{}"
    elsif @json == "{"
      @json << "}"
    end
    
    @json
  end
  
  private
  
  def escape_key(key)
    key.to_s.gsub('"', '\\"')
  end
  
  def serialize_value(value)
    case value
    when String
      "\"#{value.gsub('"', '\\"')}\""
    when Integer, Float
      value.to_s
    when true, false
      value.to_s
    when nil
      "null"
    else
      "\"#{value.to_s.gsub('"', '\\"')}\""
    end
  end
end

# Improved version with better state management
class ImprovedStringDSL
  def initialize
    @json = +""
    @level = 0
    @needs_comma = false
  end
  
  def set!(key, value = nil)
    add_comma_if_needed
    @json << "\"#{key}\":"
    
    if block_given?
      @json << "{"
      @needs_comma = false
      @level += 1
      
      yield
      
      @json << "}"
      @level -= 1
      @needs_comma = true
    else
      @json << serialize_value(value)
      @needs_comma = true
    end
    
    nil
  end
  
  def array!(collection = nil, &block)
    @json[-1] = "["  # Replace the { that set! just added
    
    if collection
      collection.each_with_index do |item, i|
        @json << "," if i > 0
        @json << "{"
        
        old_comma = @needs_comma
        @needs_comma = false
        
        yield item
        
        @json << "}"
        @needs_comma = old_comma
      end
    end
    
    nil
  end
  
  def result!
    @json.empty? ? "{}" : @json
  end
  
  private
  
  def add_comma_if_needed
    if @needs_comma
      @json << ","
    end
  end
  
  def serialize_value(value)
    case value
    when String
      "\"#{value.gsub('"', '\\"')}\""
    when Integer, Float
      value.to_s
    when true, false
      value.to_s
    when nil
      "null"
    else
      "\"#{value.to_s}\""
    end
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

puts "Testing String Concatenation DSL:"

# Test the string concat version
json = ImprovedStringDSL.new
json.set!(:users) do
  json.array!(users) do |user|
    json.set!(:id, user[:id])
    json.set!(:name, user[:name])
    json.set!(:active, user[:active])
  end
end
json.set!(:status, "success")

puts "String concat result: #{json.result!}"

# Compare with hash version
class HashDSL
  def initialize
    @stack = []
    @current = {}
    @root = @current
  end
  
  def set!(key, value = nil)
    key = key.to_s
    
    if block_given?
      @stack.push(@current)
      old_current = @current
      @current = {}
      
      result = yield
      
      if result.is_a?(Array)
        old_current[key] = result
      else
        old_current[key] = @current
      end
      
      @current = @stack.pop
    else
      @current[key] = value
    end
    
    nil
  end
  
  def array!(collection = nil, &block)
    if collection
      result = []
      collection.each do |item|
        @stack.push(@current)
        item_obj = {}
        @current = item_obj
        
        yield item
        
        result << item_obj
        @current = @stack.pop
      end
      return result
    else
      []
    end
  end
  
  def result!
    JSON.generate(@root)
  end
end

hash_json = HashDSL.new
hash_json.set!(:users) do
  hash_json.array!(users) do |user|
    hash_json.set!(:id, user[:id])
    hash_json.set!(:name, user[:name])
    hash_json.set!(:active, user[:active])
  end
end
hash_json.set!(:status, "success")

puts "Hash DSL result:      #{hash_json.result!}"

# Compare with StringWriter
class StringWriterDSL
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
    
    collection&.each do |item|
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

sw_json = StringWriterDSL.new
sw_json.set!(:users) do
  sw_json.array!(users) do |user|
    sw_json.set!(:id, user[:id])
    sw_json.set!(:name, user[:name])
    sw_json.set!(:active, user[:active])
  end
end
sw_json.set!(:status, "success")

puts "StringWriter result:  #{sw_json.result!}"

puts "\nAre outputs equivalent?"
puts "String == Hash:        #{json.result! == hash_json.result!}"
puts "String == StringWriter: #{json.result! == sw_json.result!}"

puts "\nPerformance Comparison:"
Benchmark.bm(30) do |x|
  x.report("StringWriter DSL") do
    1000.times do
      sw = StringWriterDSL.new
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
      hj = HashDSL.new
      hj.set!(:users) do
        hj.array!(users) do |user|
          hj.set!(:id, user[:id])
          hj.set!(:name, user[:name])
          hj.set!(:active, user[:active])
        end
      end
      hj.set!(:status, "success")
      result = hj.result!
    end
  end
  
  x.report("String Concat DSL") do
    1000.times do
      sj = ImprovedStringDSL.new
      sj.set!(:users) do
        sj.array!(users) do |user|
          sj.set!(:id, user[:id])
          sj.set!(:name, user[:name])
          sj.set!(:active, user[:active])
        end
      end
      sj.set!(:status, "success")
      result = sj.result!
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