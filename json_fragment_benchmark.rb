#!/usr/bin/env ruby

require 'json'
require 'benchmark'

puts "JSON::Fragment vs String Injection Benchmark (Ruby #{RUBY_VERSION}):"

# Test data
users_data = [
  {id: 1, name: "Alice", email: "alice@example.com"},
  {id: 2, name: "Bob", email: "bob@example.com"},
  {id: 3, name: "Charlie", email: "charlie@example.com"}
]

metadata = {total: 3, generated_at: "2025-08-07T15:42:30Z"}

# Pre-generate cached JSON strings (simulate cache)
cached_users_json = JSON.generate(users_data)
cached_metadata_json = JSON.generate(metadata)

puts "Cached users JSON: #{cached_users_json.length} bytes"
puts "Cached metadata JSON: #{cached_metadata_json.length} bytes"

puts "\n" + "="*60
puts "Method 1: JSON::Fragment (Official Ruby way)"

def build_with_fragments(users_json, metadata_json)
  JSON.generate({
    users: JSON::Fragment.new(users_json),
    metadata: JSON::Fragment.new(metadata_json),
    status: "success"
  })
end

result1 = build_with_fragments(cached_users_json, cached_metadata_json)
puts "Result: #{result1[0..100]}..."

puts "\n" + "="*60
puts "Method 2: String Template + gsub (Our previous approach)"

PLACEHOLDER_USERS = "__CACHED_USERS__"
PLACEHOLDER_METADATA = "__CACHED_METADATA__"

def build_with_template(users_json, metadata_json)
  # Build structure with placeholders
  template_structure = {
    users: PLACEHOLDER_USERS,
    metadata: PLACEHOLDER_METADATA,
    status: "success"
  }
  
  # Generate JSON with placeholders
  json_with_placeholders = JSON.generate(template_structure)
  
  # Replace placeholders with actual JSON
  final_json = json_with_placeholders
    .gsub("\"#{PLACEHOLDER_USERS}\"", users_json)
    .gsub("\"#{PLACEHOLDER_METADATA}\"", metadata_json)
  
  final_json
end

result2 = build_with_template(cached_users_json, cached_metadata_json)
puts "Result: #{result2[0..100]}..."

puts "\n" + "="*60
puts "Method 3: Manual String Building"

def build_with_strings(users_json, metadata_json)
  parts = []
  parts << '{"users":'
  parts << users_json
  parts << ',"metadata":'
  parts << metadata_json
  parts << ',"status":"success"}'
  parts.join
end

result3 = build_with_strings(cached_users_json, cached_metadata_json)
puts "Result: #{result3[0..100]}..."

puts "\n" + "="*60
puts "Method 4: No Caching (Baseline - build from scratch)"

def build_from_scratch(users_data, metadata)
  JSON.generate({
    users: users_data,
    metadata: metadata,
    status: "success"
  })
end

result4 = build_from_scratch(users_data, metadata)
puts "Result: #{result4[0..100]}..."

puts "\n" + "="*60
puts "Verify all methods produce equivalent output:"
puts "Fragment == Template: #{result1 == result2}"
puts "Fragment == Manual: #{result1 == result3}"
puts "Fragment == Scratch: #{result1 == result4}"

puts "\n" + "="*60
puts "Performance Comparison (10,000 iterations):"

Benchmark.bm(20) do |x|
  x.report("JSON::Fragment") do
    10000.times { build_with_fragments(cached_users_json, cached_metadata_json) }
  end
  
  x.report("String Template") do
    10000.times { build_with_template(cached_users_json, cached_metadata_json) }
  end
  
  x.report("Manual String") do
    10000.times { build_with_strings(cached_users_json, cached_metadata_json) }
  end
  
  x.report("No Cache (baseline)") do
    10000.times { build_from_scratch(users_data, metadata) }
  end
end

puts "\n" + "="*60
puts "Complex nested example with multiple fragments:"

# Simulate more complex caching scenario
header_data = {logo: "company.png", nav: ["Home", "About", "Contact"]}
footer_data = {copyright: "2025", links: ["Privacy", "Terms"]}

cached_header_json = JSON.generate(header_data)
cached_footer_json = JSON.generate(footer_data)

def build_complex_with_fragments(users_json, metadata_json, header_json, footer_json)
  JSON.generate({
    header: JSON::Fragment.new(header_json),
    content: {
      users: JSON::Fragment.new(users_json),
      metadata: JSON::Fragment.new(metadata_json)
    },
    footer: JSON::Fragment.new(footer_json),
    page_info: {
      generated_at: Time.now.to_f,
      cache_version: "v1.2.3"
    }
  })
end

complex_result = build_complex_with_fragments(
  cached_users_json, 
  cached_metadata_json, 
  cached_header_json, 
  cached_footer_json
)

puts "Complex result: #{complex_result[0..150]}..."

puts "\n" + "="*60
puts "Performance for complex nested fragments (1,000 iterations):"

Benchmark.bm(20) do |x|
  x.report("Complex Fragments") do
    1000.times do
      build_complex_with_fragments(
        cached_users_json, 
        cached_metadata_json, 
        cached_header_json, 
        cached_footer_json
      )
    end
  end
  
  x.report("Complex No Cache") do
    1000.times do
      JSON.generate({
        header: header_data,
        content: {
          users: users_data,
          metadata: metadata
        },
        footer: footer_data,
        page_info: {
          generated_at: Time.now.to_f,
          cache_version: "v1.2.3"
        }
      })
    end
  end
end

puts "\n" + "="*60
puts "Conclusion:"
puts "JSON::Fragment is the official Ruby way to combine cached JSON strings"
puts "without parsing them. Perfect for props_template caching scenarios!"