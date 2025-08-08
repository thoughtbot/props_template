#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'
require 'json'

# Test data
USERS = 1000.times.map do |i|
  {
    id: i,
    name: "User #{i}",
    email: "user#{i}@example.com",
    active: i.even?,
    score: rand(100..999) / 10.0,
    created_at: Time.now - rand(365) * 86400
  }
end

# Oj::StringWriter approach
def build_json_with_oj(users)
  stream = Oj::StringWriter.new(mode: :rails)
  
  stream.push_object
  stream.push_key("users")
  stream.push_array
  
  users.each_with_index do |user, i|
    stream.push_object
    stream.push_value(user[:id], "id")
    stream.push_value(user[:name], "name") 
    stream.push_value(user[:email], "email")
    stream.push_value(user[:active], "active")
    stream.push_value(user[:score], "score")
    stream.push_value(user[:created_at].iso8601, "created_at")
    stream.pop
  end
  
  stream.pop # close array
  stream.pop # close object
  
  stream.raw_json
end

# Simple Ruby string concatenation
def build_json_with_string(users)
  json = String.new(capacity: 100_000)
  
  json << '{"users":['
  
  users.each_with_index do |user, i|
    json << ',' if i > 0
    json << '{'
    json << "\"id\":#{user[:id]},"
    json << "\"name\":\"#{escape_json(user[:name])}\","
    json << "\"email\":\"#{escape_json(user[:email])}\","
    json << "\"active\":#{user[:active]},"
    json << "\"score\":#{user[:score]},"
    json << "\"created_at\":\"#{user[:created_at].iso8601}\""
    json << '}'
  end
  
  json << ']}'
  json
end

# Optimized Ruby string concatenation with frozen strings
def build_json_with_optimized_string(users)
  json = +""
  json << '{"users":['
  
  users.each_with_index do |user, i|
    json << ',' if i > 0
    json << '{"id":'
    json << user[:id].to_s
    json << ',"name":"'
    json << escape_json(user[:name])
    json << '","email":"'  
    json << escape_json(user[:email])
    json << '","active":'
    json << user[:active].to_s
    json << ',"score":'
    json << user[:score].to_s
    json << ',"created_at":"'
    json << user[:created_at].iso8601
    json << '"}'
  end
  
  json << ']}'
end

# Ruby with pre-allocated buffer
def build_json_with_buffer(users)
  # Estimate size and pre-allocate
  estimated_size = users.length * 200 + 1000
  json = String.new(capacity: estimated_size)
  
  json << '{"users":['
  
  users.each_with_index do |user, i|
    json << ',' if i > 0
    json << sprintf('{"id":%d,"name":"%s","email":"%s","active":%s,"score":%s,"created_at":"%s"}',
                   user[:id],
                   escape_json(user[:name]),
                   escape_json(user[:email]), 
                   user[:active],
                   user[:score],
                   user[:created_at].iso8601)
  end
  
  json << ']}'
end

# Simple JSON escaping (minimal implementation)
def escape_json(str)
  str.gsub(/["\\]/, '\"' => '\\"', '\\' => '\\\\')
end

# Verify all methods produce valid JSON
puts "Verifying outputs..."
oj_result = build_json_with_oj(USERS.first(5))
string_result = build_json_with_string(USERS.first(5))
optimized_result = build_json_with_optimized_string(USERS.first(5))
buffer_result = build_json_with_buffer(USERS.first(5))

# Parse to verify they're valid JSON
begin
  JSON.parse(oj_result)
  JSON.parse(string_result) 
  JSON.parse(optimized_result)
  JSON.parse(buffer_result)
  puts "✅ All outputs produce valid JSON"
rescue JSON::ParserError => e
  puts "❌ Invalid JSON produced: #{e}"
  exit 1
end

puts "\nBenchmarking with #{USERS.length} users...\n"

Benchmark.bm(25) do |x|
  x.report("Oj::StringWriter") do
    1000.times { build_json_with_oj(USERS) }
  end
  
  x.report("String concatenation") do
    1000.times { build_json_with_string(USERS) }
  end
  
  x.report("Optimized string (<<)") do  
    1000.times { build_json_with_optimized_string(USERS) }
  end
  
  x.report("Pre-allocated buffer") do
    1000.times { build_json_with_buffer(USERS) }
  end
end

puts "\nMemory allocation test (single run):"

require 'objspace'

GC.start
before_oj = ObjectSpace.count_objects
build_json_with_oj(USERS)
after_oj = ObjectSpace.count_objects

GC.start  
before_string = ObjectSpace.count_objects
build_json_with_optimized_string(USERS)
after_string = ObjectSpace.count_objects

puts "Oj allocated objects: #{after_oj[:TOTAL] - before_oj[:TOTAL]}"
puts "String allocated objects: #{after_string[:TOTAL] - before_string[:TOTAL]}"

puts "\nOutput size: #{build_json_with_oj(USERS).bytesize} bytes"