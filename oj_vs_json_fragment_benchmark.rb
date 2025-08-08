#!/usr/bin/env ruby

require 'bundler/setup'
require 'oj'
require 'json'
require 'benchmark'

puts "Oj::StringWriter vs JSON::Fragment Benchmark (Ruby #{RUBY_VERSION}):"

# Test data - simulate props_template scenario
users_data = (1..100).map { |i|
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
    }
  }
}

metadata = {
  total: users_data.length,
  generated_at: Time.now.to_s,
  version: "1.0.0"
}

# Pre-generate cached JSON strings
cached_users_json = JSON.generate(users_data)
cached_metadata_json = JSON.generate(metadata)

puts "Data sizes:"
puts "Users data: #{cached_users_json.bytesize} bytes"
puts "Metadata: #{cached_metadata_json.bytesize} bytes"

puts "\n" + "="*70

# Method 1: Oj::StringWriter with push_json (props_template style)
def build_with_oj_stringwriter(users_json, metadata_json)
  json = Oj::StringWriter.new
  
  json.push_object
  
  json.push_key('users')
  json.push_json(users_json)  # Inject cached JSON string
  
  json.push_key('metadata')
  json.push_json(metadata_json)  # Inject cached JSON string
  
  json.push_key('status')
  json.push_value('success')
  
  json.push_key('extra_field')
  json.push_value('some_value')
  
  json.pop_all
  
  json.to_s
end

# Method 2: JSON::Fragment (native Ruby)
def build_with_json_fragment(users_json, metadata_json)
  JSON.generate({
    users: JSON::Fragment.new(users_json),
    metadata: JSON::Fragment.new(metadata_json),
    status: 'success',
    extra_field: 'some_value'
  })
end

# Method 3: Pure Oj::StringWriter (no caching) - simplified
def build_with_oj_no_cache(users_data, metadata)
  json = Oj::StringWriter.new
  
  json.push_object
  
  json.push_key('users')
  json.push_value(users_data)  # Let Oj handle the array
  
  json.push_key('metadata')
  json.push_value(metadata)  # Let Oj handle the hash
  
  json.push_key('status')
  json.push_value('success')
  
  json.push_key('extra_field')
  json.push_value('some_value')
  
  json.pop_all
  
  json.to_s
end

# Method 4: Pure JSON.generate (no caching)
def build_with_json_no_cache(users_data, metadata)
  JSON.generate({
    users: users_data,
    metadata: metadata,
    status: 'success',
    extra_field: 'some_value'
  })
end

# Method 5: Oj.dump (no caching)
def build_with_oj_dump(users_data, metadata)
  Oj.dump({
    users: users_data,
    metadata: metadata,
    status: 'success',
    extra_field: 'some_value'
  })
end

puts "Testing all methods produce equivalent results..."

result1 = build_with_oj_stringwriter(cached_users_json, cached_metadata_json)
result2 = build_with_json_fragment(cached_users_json, cached_metadata_json)
result3 = build_with_oj_no_cache(users_data, metadata)
result4 = build_with_json_no_cache(users_data, metadata)
result5 = build_with_oj_dump(users_data, metadata)

puts "Oj StringWriter result: #{result1.length} bytes"
puts "JSON Fragment result: #{result2.length} bytes"
puts "Oj No Cache result: #{result3.length} bytes"
puts "JSON No Cache result: #{result4.length} bytes"
puts "Oj Dump result: #{result5.length} bytes"

# Parse and compare structure (not exact string match due to potential ordering)
parsed1 = JSON.parse(result1)
parsed2 = JSON.parse(result2)
parsed3 = JSON.parse(result3)
parsed4 = JSON.parse(result4)
parsed5 = JSON.parse(result5)

puts "All results structurally equivalent: #{[parsed1, parsed2, parsed3, parsed4, parsed5].uniq.length == 1}"

puts "\n" + "="*70
puts "PERFORMANCE COMPARISON (1,000 iterations):"
puts "Testing caching scenarios vs non-caching scenarios"

Benchmark.bm(25) do |x|
  x.report("Oj::StringWriter+push_json") do
    1000.times { build_with_oj_stringwriter(cached_users_json, cached_metadata_json) }
  end
  
  x.report("JSON::Fragment") do
    1000.times { build_with_json_fragment(cached_users_json, cached_metadata_json) }
  end
  
  x.report("Oj::StringWriter (no cache)") do
    1000.times { build_with_oj_no_cache(users_data, metadata) }
  end
  
  x.report("JSON.generate (no cache)") do
    1000.times { build_with_json_no_cache(users_data, metadata) }
  end
  
  x.report("Oj.dump (no cache)") do
    1000.times { build_with_oj_dump(users_data, metadata) }
  end
end

puts "\n" + "="*70
puts "MEMORY USAGE COMPARISON:"

# Test memory patterns with smaller iterations to see object allocation
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

puts "\nMemory allocation per 100 iterations:"

oj_memory = measure_memory do
  100.times { build_with_oj_stringwriter(cached_users_json, cached_metadata_json) }
end

json_memory = measure_memory do
  100.times { build_with_json_fragment(cached_users_json, cached_metadata_json) }
end

puts "Oj StringWriter: #{oj_memory[:total_allocated]} total objects, #{oj_memory[:string_objects]} strings"
puts "JSON Fragment: #{json_memory[:total_allocated]} total objects, #{json_memory[:string_objects]} strings"

puts "\n" + "="*70
puts "COMPLEX NESTED CACHING SCENARIO:"

# Test more complex props_template-like scenario
header_json = JSON.generate({logo: "company.png", nav: ["Home", "About"]})
sidebar_json = JSON.generate({widgets: ["weather", "news", "calendar"]})
footer_json = JSON.generate({copyright: "2025", links: ["Privacy", "Terms"]})

def build_complex_oj(users_json, metadata_json, header_json, sidebar_json, footer_json)
  json = Oj::StringWriter.new
  
  json.push_object
  
  json.push_key('header')
  json.push_json(header_json)
  
  json.push_key('content')
  json.push_object
  json.push_key('users')
  json.push_json(users_json)
  json.push_key('sidebar')
  json.push_json(sidebar_json)
  json.pop
  
  json.push_key('metadata')
  json.push_json(metadata_json)
  
  json.push_key('footer')
  json.push_json(footer_json)
  
  json.push_key('page_info')
  json.push_object
  json.push_key('generated_at')
  json.push_value(Time.now.to_f)
  json.push_key('cache_version')
  json.push_value('v2.1.0')
  json.pop
  
  json.pop_all
  json.to_s
end

def build_complex_json_fragment(users_json, metadata_json, header_json, sidebar_json, footer_json)
  JSON.generate({
    header: JSON::Fragment.new(header_json),
    content: {
      users: JSON::Fragment.new(users_json),
      sidebar: JSON::Fragment.new(sidebar_json)
    },
    metadata: JSON::Fragment.new(metadata_json),
    footer: JSON::Fragment.new(footer_json),
    page_info: {
      generated_at: Time.now.to_f,
      cache_version: 'v2.1.0'
    }
  })
end

puts "Complex nested scenario (500 iterations):"

Benchmark.bm(25) do |x|
  x.report("Complex Oj StringWriter") do
    500.times do
      build_complex_oj(cached_users_json, cached_metadata_json, header_json, sidebar_json, footer_json)
    end
  end
  
  x.report("Complex JSON Fragment") do
    500.times do
      build_complex_json_fragment(cached_users_json, cached_metadata_json, header_json, sidebar_json, footer_json)
    end
  end
end

puts "\n" + "="*70
puts "SUMMARY:"
puts "• Oj::StringWriter + push_json: C-level performance, streaming approach"
puts "• JSON::Fragment: Native Ruby, clean API, official support"
puts "• Both avoid parsing cached JSON strings"
puts "• Performance difference shows the cost/benefit of each approach"