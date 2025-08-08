#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'
require 'json'

# Hash-based DSL that mimics props_template API
class HashDSL
  def initialize
    @stack = []
    @current = {}
    @root = @current
  end
  
  def set!(key, value = nil)
    key = key.to_s
    
    if block_given?
      # Save current context
      @stack.push([@current, key])
      new_obj = {}
      @current[key] = new_obj
      @current = new_obj
      
      yield
      
      # Restore context
      @current, _ = @stack.pop
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
      result
    else
      # Manual array building - return array that gets populated
      []
    end
  end
  
  def result!
    JSON.generate(@root)
  end
end

# Test the real props template base too
class RealPropsBase
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
      key = key.to_s
      @stream.push_key(key)
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
    
    if collection
      collection.each do |item|
        @scope = nil
        yield item
        if @scope.nil?
          @stream.push_object
        end
        @stream.pop
      end
    else
      yield
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

# Test data
users = 20.times.map do |i|
  {
    id: i,
    name: "User #{i}",
    email: "user#{i}@example.com",
    active: i.even?
  }
end

puts "Hash-based DSL vs StringWriter DSL (Ruby #{RUBY_VERSION}):"

Benchmark.bm(40) do |x|
  x.report("Props template (StringWriter DSL)") do
    1000.times do
      json = RealPropsBase.new
      
      json.set!(:users) do
        json.array!(users) do |user|
          json.set!(:id, user[:id])
          json.set!(:name, user[:name])
          json.set!(:email, user[:email])
          json.set!(:active, user[:active])
        end
      end
      
      json.set!(:status, "success")
      result = json.result!
    end
  end
  
  x.report("Hash-based DSL") do
    1000.times do
      json = HashDSL.new
      
      json.set!(:users) do
        json.array!(users) do |user|
          json.set!(:id, user[:id])
          json.set!(:name, user[:name])
          json.set!(:email, user[:email])
          json.set!(:active, user[:active])
        end
      end
      
      json.set!(:status, "success")
      result = json.result!
    end
  end
  
  x.report("Direct hash building") do
    1000.times do
      result_hash = {
        users: users.map do |user|
          {
            id: user[:id],
            name: user[:name],
            email: user[:email],
            active: user[:active]
          }
        end,
        status: "success"
      }
      
      json = JSON.generate(result_hash)
    end
  end
  
  x.report("Hash DSL + Oj.dump") do
    1000.times do
      json = HashDSL.new
      
      json.set!(:users) do
        json.array!(users) do |user|
          json.set!(:id, user[:id])
          json.set!(:name, user[:name])
          json.set!(:email, user[:email])
          json.set!(:active, user[:active])
        end
      end
      
      json.set!(:status, "success")
      
      # Extract hash and use Oj
      result = Oj.dump(json.instance_variable_get(:@root), mode: :rails)
    end
  end
end

# Test equivalence
puts "\nTesting output equivalence:"

# StringWriter version
json1 = RealPropsBase.new
json1.set!(:test) do
  json1.array!([{id: 1, name: "Test"}]) do |item|
    json1.set!(:id, item[:id])
    json1.set!(:name, item[:name])
  end
end
result1 = json1.result!

# Hash version
json2 = HashDSL.new  
json2.set!(:test) do
  json2.array!([{id: 1, name: "Test"}]) do |item|
    json2.set!(:id, item[:id])
    json2.set!(:name, item[:name])
  end
end
result2 = json2.result!

puts "StringWriter result: #{result1}"
puts "Hash DSL result:     #{result2}"
puts "Equal? #{result1 == result2}"

# Test more complex nesting
puts "\nTesting complex nesting:"

json3 = HashDSL.new
json3.set!(:user) do
  json3.set!(:id, 1)
  json3.set!(:profile) do
    json3.set!(:name, "John")
    json3.set!(:settings) do
      json3.set!(:theme, "dark")
    end
  end
end
complex_result = json3.result!
puts "Complex hash result: #{complex_result}"