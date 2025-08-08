#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'
require 'json'

# Test combining string concat with push_json
class HybridJsonBuilder
  def initialize
    @stream = Oj::StringWriter.new(mode: :rails)
  end
  
  # Use string building for structure
  def push_string(str)
    @stream.push_json(str)  # Inject raw string
  end
  
  # Use push_json for cached fragments
  def push_cached_json(json_string)
    @stream.push_json(json_string)
  end
  
  def result
    @stream.raw_json
  end
end

puts "Testing hybrid approach combining string building + push_json:"

# Test data
users = 20.times.map do |i|
  {
    id: i,
    name: "User #{i}",
    email: "user#{i}@example.com"
  }
end

# Simulate cached user profiles (pre-serialized JSON)
cached_profiles = users.map do |user|
  JSON.generate({
    bio: "I am #{user[:name]}",
    preferences: { theme: "dark", lang: "en" },
    stats: { posts: rand(10), followers: rand(100) }
  })
end

Benchmark.bm(35) do |x|
  x.report("Pure Oj::StringWriter") do
    1000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_object
      stream.push_key("users")
      stream.push_array
      
      users.each_with_index do |user, i|
        stream.push_object
        stream.push_value(user[:id], "id")
        stream.push_value(user[:name], "name")
        stream.push_value(user[:email], "email")
        stream.push_key("profile")
        stream.push_json(cached_profiles[i])  # Cached profile
        stream.pop
      end
      
      stream.pop
      stream.pop
      stream.raw_json
    end
  end
  
  x.report("Pure String Concatenation") do
    1000.times do
      json = +'{"users":['
      users.each_with_index do |user, i|
        json << "," if i > 0
        json << '{"id":' << user[:id].to_s << 
               ',"name":"' << user[:name] << 
               '","email":"' << user[:email] << 
               '","profile":' << cached_profiles[i] << '}'
      end
      json << ']}'
    end
  end
  
  x.report("Hybrid: String structure + push_json") do
    1000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      
      # Build structure with raw strings
      stream.push_json('{"users":[')
      
      users.each_with_index do |user, i|
        stream.push_json(",") if i > 0
        
        # Use string building for simple fields
        user_json = '{"id":' + user[:id].to_s + 
                   ',"name":"' + user[:name] + 
                   '","email":"' + user[:email] + 
                   '","profile":'
        stream.push_json(user_json)
        
        # Use push_json for cached complex data
        stream.push_json(cached_profiles[i])
        
        stream.push_json('}')
      end
      
      stream.push_json(']}')
      stream.raw_json
    end
  end
  
  x.report("Hybrid: Optimized") do
    1000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      
      # Pre-build the structure parts
      stream.push_json('{"users":[')
      
      users.each_with_index do |user, i|
        # Build user structure as one string
        prefix = (i > 0 ? "," : "") + 
                '{"id":' + user[:id].to_s + 
                ',"name":"' + user[:name] + 
                '","email":"' + user[:email] + 
                '","profile":'
        
        stream.push_json(prefix)
        stream.push_json(cached_profiles[i])  # Cached part
        stream.push_json('}')
      end
      
      stream.push_json(']}')
      stream.raw_json
    end
  end
  
  x.report("Hybrid: Buffer approach") do
    1000.times do
      parts = []
      parts << '{"users":['
      
      users.each_with_index do |user, i|
        parts << "," if i > 0
        parts << '{"id":' << user[:id].to_s << 
                ',"name":"' << user[:name] << 
                '","email":"' << user[:email] << 
                '","profile":'
        parts << cached_profiles[i]  # Cached JSON
        parts << '}'
      end
      
      parts << ']}'
      
      # Use Oj to inject the final result
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_json(parts.join)
      stream.raw_json
    end
  end
end

puts "\nTesting push_json with different input types:"

Benchmark.bm(25) do |x|
  json_string = '{"valid":"json"}'
  malformed_string = '{"missing":quote}'
  partial_string = '"just a string"'
  number_string = "42"
  
  x.report("push_json valid JSON") do
    10000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_json(json_string)
      stream.raw_json
    end
  end
  
  x.report("push_json malformed") do
    10000.times do
      stream = Oj::StringWriter.new(mode: :rails)  
      stream.push_json(malformed_string)
      stream.raw_json
    end
  end
  
  x.report("push_json partial") do
    10000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_json(partial_string)  
      stream.raw_json
    end
  end
  
  x.report("push_json number") do
    10000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_json(number_string)
      stream.raw_json
    end
  end
end

puts "\nTesting whether push_json validates input:"
begin
  stream = Oj::StringWriter.new(mode: :rails)
  stream.push_json('invalid json {')
  result = stream.raw_json
  puts "✓ push_json accepts malformed JSON: #{result}"
rescue => e
  puts "✗ push_json validates: #{e.message}"
end