#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'
require 'json'

puts "Hash vs Stream - Careful Benchmark (Ruby #{RUBY_VERSION}):"

# Simple test data first
users = 20.times.map do |i|
  {
    id: i,
    name: "User #{i}",
    email: "user#{i}@example.com",
    active: i.even?
  }
end

puts "Testing with #{users.length} users, running each approach 1000 times..."

Benchmark.bm(30) do |x|
  x.report("Oj::StringWriter streaming") do
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
      
      stream.pop # close array
      stream.push_value("success", "status")
      stream.pop # close object
      
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

# Let's verify the outputs are the same
puts "\nVerifying outputs are equivalent..."

# Oj streaming result
stream = Oj::StringWriter.new(mode: :rails)
stream.push_object
stream.push_key("users")
stream.push_array
users.first(2).each do |user|
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
oj_stream_result = stream.raw_json

# Hash result
hash_result_obj = {
  users: users.first(2).map do |user|
    {
      id: user[:id],
      name: user[:name],
      email: user[:email],
      active: user[:active]
    }
  end,
  status: "success"
}
hash_result = JSON.generate(hash_result_obj)

puts "Oj streaming result:"
puts oj_stream_result
puts "\nHash result:"  
puts hash_result
puts "\nAre they equal? #{oj_stream_result == hash_result}"

# Let's also test just the core operations
puts "\nTesting just the core operations (10,000 iterations):"

Benchmark.bm(30) do |x|
  x.report("Just Oj StringWriter setup") do
    10000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_object
      stream.push_value("test", "key")
      stream.pop
      result = stream.raw_json
    end
  end
  
  x.report("Just hash + JSON.generate") do
    10000.times do
      hash = { key: "test" }
      result = JSON.generate(hash)
    end
  end
  
  x.report("Just hash + Oj.dump") do
    10000.times do
      hash = { key: "test" }
      result = Oj.dump(hash, mode: :rails)
    end
  end
end