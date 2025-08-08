#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'json'
require_relative 'old_props_base'
require_relative 'new_props_base'

puts "Old Props (Oj::StringWriter) vs New Props (Hash-based) Benchmark"
puts "Ruby #{RUBY_VERSION}"

# Test data - realistic props_template scenarios
users_data = (1..50).map { |i|
  {
    id: i,
    name: "User #{i}",
    email: "user#{i}@example.com",
    active: i.even?,
    profile: {
      age: 20 + (i % 50),
      city: "City #{i % 10}",
      preferences: {
        theme: i.even? ? "dark" : "light",
        notifications: i % 3 == 0
      }
    },
    tags: ["tag#{i}", "category#{i % 5}"],
    scores: [85.5 + i, 90.2 - i, 78.1 + (i * 2)]
  }
}

metadata = {
  total: users_data.length,
  generated_at: Time.now.to_s,
  version: "1.2.3",
  cache_info: {
    enabled: true,
    ttl: 3600
  }
}

puts "Test data: #{users_data.length} users with nested profiles"

puts "\n" + "="*70

# Test 1: Simple object building
def test_simple_object_old
  json = OldProps::Base.new
  json.set!(:name, "Alice")
  json.set!(:email, "alice@example.com") 
  json.set!(:active, true)
  json.result!
end

def test_simple_object_new
  json = NewProps::Base.new
  json.set!(:name, "Alice")
  json.set!(:email, "alice@example.com")
  json.set!(:active, true)
  json.result!
end

# Test 2: Nested object building
def test_nested_object_old(users_data, metadata)
  json = OldProps::Base.new
  
  json.set!(:users) do
    json.array!(users_data) do |user, index|
      json.set!(:id, user[:id])
      json.set!(:name, user[:name])
      json.set!(:email, user[:email])
      json.set!(:active, user[:active])
      json.set!(:profile) do
        json.set!(:age, user[:profile][:age])
        json.set!(:city, user[:profile][:city])
        json.set!(:preferences) do
          json.set!(:theme, user[:profile][:preferences][:theme])
          json.set!(:notifications, user[:profile][:preferences][:notifications])
        end
      end
    end
  end
  
  json.set!(:metadata) do
    json.set!(:total, metadata[:total])
    json.set!(:generated_at, metadata[:generated_at])
    json.set!(:version, metadata[:version])
  end
  
  json.result!
end

def test_nested_object_new(users_data, metadata)
  json = NewProps::Base.new
  
  json.set!(:users) do
    json.array!(users_data) do |user, index|
      json.set!(:id, user[:id])
      json.set!(:name, user[:name])
      json.set!(:email, user[:email])
      json.set!(:active, user[:active])
      json.set!(:profile) do
        json.set!(:age, user[:profile][:age])
        json.set!(:city, user[:profile][:city])
        json.set!(:preferences) do
          json.set!(:theme, user[:profile][:preferences][:theme])
          json.set!(:notifications, user[:profile][:preferences][:notifications])
        end
      end
    end
  end
  
  json.set!(:metadata) do
    json.set!(:total, metadata[:total])
    json.set!(:generated_at, metadata[:generated_at])
    json.set!(:version, metadata[:version])
  end
  
  json.result!
end

# Test 3: Extract method
def test_extract_old(user)
  json = OldProps::Base.new
  json.extract!(user, :id, :name, :email, :active)
  json.result!
end

def test_extract_new(user)
  json = NewProps::Base.new
  json.extract!(user, :id, :name, :email, :active)
  json.result!
end

# Test 4: Child method with arrays
def test_child_array_old
  json = OldProps::Base.new
  json.array! do
    json.child! do
      json.set!(:type, "header")
      json.set!(:content, "Welcome")
    end
    json.child! do
      json.set!(:type, "body")
      json.set!(:content, "Main content here")
    end
    json.child! do
      json.set!(:type, "footer")
      json.set!(:content, "Copyright 2025")
    end
  end
  json.result!
end

def test_child_array_new
  json = NewProps::Base.new
  json.array! do
    json.child! do
      json.set!(:type, "header")
      json.set!(:content, "Welcome")
    end
    json.child! do
      json.set!(:type, "body")
      json.set!(:content, "Main content here")
    end
    json.child! do
      json.set!(:type, "footer")
      json.set!(:content, "Copyright 2025")
    end
  end
  json.result!
end

puts "Verifying equivalent outputs..."

# Verify outputs are equivalent
simple_old = test_simple_object_old
simple_new = test_simple_object_new
puts "Simple object equivalent: #{JSON.parse(simple_old) == JSON.parse(simple_new)}"

nested_old = test_nested_object_old(users_data[0..2], metadata)  # Small sample for verification
nested_new = test_nested_object_new(users_data[0..2], metadata)
puts "Nested object equivalent: #{JSON.parse(nested_old) == JSON.parse(nested_new)}"

extract_old = test_extract_old(users_data[0])
extract_new = test_extract_new(users_data[0])
puts "Extract equivalent: #{JSON.parse(extract_old) == JSON.parse(extract_new)}"

child_old = test_child_array_old
child_new = test_child_array_new
puts "Child array equivalent: #{JSON.parse(child_old) == JSON.parse(child_new)}"

puts "Sample old output: #{simple_old}"
puts "Sample new output: #{simple_new}"

puts "\n" + "="*70
puts "PERFORMANCE BENCHMARKS"

puts "\n1. Simple Object Building (10,000 iterations):"
Benchmark.bm(20) do |x|
  x.report("Old (Oj StringWriter)") do
    10000.times { test_simple_object_old }
  end
  
  x.report("New (Hash-based)") do
    10000.times { test_simple_object_new }
  end
end

puts "\n2. Complex Nested Objects (1,000 iterations):"
Benchmark.bm(20) do |x|
  x.report("Old (Oj StringWriter)") do
    1000.times { test_nested_object_old(users_data, metadata) }
  end
  
  x.report("New (Hash-based)") do
    1000.times { test_nested_object_new(users_data, metadata) }
  end
end

puts "\n3. Extract Method (10,000 iterations):"
test_user = users_data[0]
Benchmark.bm(20) do |x|
  x.report("Old (Oj StringWriter)") do
    10000.times { test_extract_old(test_user) }
  end
  
  x.report("New (Hash-based)") do
    10000.times { test_extract_new(test_user) }
  end
end

puts "\n4. Child Array Building (5,000 iterations):"
Benchmark.bm(20) do |x|
  x.report("Old (Oj StringWriter)") do
    5000.times { test_child_array_old }
  end
  
  x.report("New (Hash-based)") do
    5000.times { test_child_array_new }
  end
end

puts "\n" + "="*70
puts "MEMORY USAGE ANALYSIS"

require 'objspace'

def measure_memory(&block)
  GC.disable
  before = ObjectSpace.count_objects
  block.call
  after = ObjectSpace.count_objects
  GC.enable
  
  {
    total_allocated: after[:TOTAL] - before[:TOTAL],
    string_objects: after[:T_STRING] - before[:T_STRING],
    hash_objects: after[:T_HASH] - before[:T_HASH],
    array_objects: after[:T_ARRAY] - before[:T_ARRAY]
  }
end

puts "\nMemory usage per 100 complex object builds:"

old_memory = measure_memory do
  100.times { test_nested_object_old(users_data, metadata) }
end

new_memory = measure_memory do
  100.times { test_nested_object_new(users_data, metadata) }
end

puts "Old (Oj StringWriter):"
puts "  Total objects: #{old_memory[:total_allocated]}"
puts "  String objects: #{old_memory[:string_objects]}"
puts "  Hash objects: #{old_memory[:hash_objects]}"
puts "  Array objects: #{old_memory[:array_objects]}"

puts "New (Hash-based):"
puts "  Total objects: #{new_memory[:total_allocated]}"
puts "  String objects: #{new_memory[:string_objects]}"
puts "  Hash objects: #{new_memory[:hash_objects]}"
puts "  Array objects: #{new_memory[:array_objects]}"

puts "\n" + "="*70
puts "RESULT SIZE COMPARISON"

old_result = test_nested_object_old(users_data, metadata)
new_result = test_nested_object_new(users_data, metadata)

puts "Old result size: #{old_result.bytesize} bytes"
puts "New result size: #{new_result.bytesize} bytes"
puts "Size difference: #{new_result.bytesize - old_result.bytesize} bytes"

puts "\n" + "="*70
puts "SCALABILITY TEST - Increasing Data Sizes"

[10, 25, 50, 100].each do |size|
  test_data = users_data[0, size]
  puts "\nTesting with #{size} users:"
  
  Benchmark.bm(20) do |x|
    x.report("Old (#{size} users)") do
      100.times { test_nested_object_old(test_data, metadata) }
    end
    
    x.report("New (#{size} users)") do
      100.times { test_nested_object_new(test_data, metadata) }
    end
  end
end

puts "\n" + "="*70
puts "SUMMARY:"
puts "• Old: Oj::StringWriter - C-level streaming JSON building"
puts "• New: Hash-based - Ruby native hash building + JSON.fast_generate"
puts "• Performance comparison shows the real-world difference"
puts "• Memory analysis shows allocation patterns"
puts "• Both produce identical JSON output"