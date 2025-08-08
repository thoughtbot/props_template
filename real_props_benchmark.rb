#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'
require 'json'

# Simulate the actual Props::Base behavior
class PropsBase
  def initialize
    @stream = Oj::StringWriter.new(mode: :rails)
    @scope = nil
  end
  
  def set!(key, value = nil)
    if @scope.nil?
      @scope = :object
      @stream.push_object  # Lazy object creation
    end
    
    if block_given?
      key = key.to_s
      @stream.push_key(key)
      @scope = nil  # Reset scope for block content
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
        @scope = nil  # Reset for each item
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

puts "Real Props Template Pattern vs Hash Building (Ruby #{RUBY_VERSION}):"

Benchmark.bm(35) do |x|
  x.report("Props template pattern (real)") do
    1000.times do
      json = PropsBase.new
      
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
  
  x.report("My wrong streaming approach") do
    1000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      
      stream.push_object
      stream.push_key("users")
      stream.push_array
      
      users.each do |user|
        stream.push_object
        stream.push_value(user[:id], "id")
        stream.push_value(user[:name], "name")
        stream.push_value(user[:email], "email")
        stream.push_value(user[:active], "active")
        stream.pop
      end
      
      stream.pop
      stream.push_value("success", "status")
      stream.pop
      
      result = stream.raw_json
    end
  end
  
  x.report("Hash build + JSON.generate") do
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
  
  x.report("Hash build + Oj.dump") do
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
      
      json = Oj.dump(result_hash, mode: :rails)
    end
  end
end

# Test that outputs are equivalent
puts "\nTesting output equivalence:"

json = PropsBase.new
json.set!(:users) do
  json.array!(users.first(2)) do |user|
    json.set!(:id, user[:id])
    json.set!(:name, user[:name])
  end
end
json.set!(:status, "success")
props_result = json.result!

hash_result = JSON.generate({
  users: users.first(2).map { |u| { id: u[:id], name: u[:name] } },
  status: "success"
})

puts "Props result: #{props_result}"
puts "Hash result:  #{hash_result}"
puts "Equal? #{props_result == hash_result}"