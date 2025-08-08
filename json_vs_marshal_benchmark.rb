#!/usr/bin/env ruby

require 'benchmark'
require 'json'

puts "JSON.parse vs Marshal Benchmark (Ruby #{RUBY_VERSION}):"

# Test data - various sizes and complexities
small_data = { id: 1, name: "Alice", email: "alice@example.com" }

medium_data = {
  users: (1..100).map { |i| 
    { id: i, name: "User#{i}", email: "user#{i}@example.com", active: i.even? }
  },
  metadata: { total: 100, generated_at: Time.now.to_s }
}

large_data = {
  posts: (1..1000).map { |i|
    {
      id: i,
      title: "Post #{i}" * 10,  # Make it bigger
      content: "Content for post #{i}" * 20,
      tags: ["tag#{i}", "category#{i % 5}", "type#{i % 3}"],
      author: {
        id: i % 50,
        name: "Author #{i % 50}",
        email: "author#{i % 50}@example.com"
      },
      comments: (1..5).map { |j|
        {
          id: j,
          text: "Comment #{j} on post #{i}",
          author: "Commenter #{j}"
        }
      }
    }
  }
}

# Generate serialized versions
small_json = JSON.generate(small_data)
small_marshal = Marshal.dump(small_data)

medium_json = JSON.generate(medium_data)
medium_marshal = Marshal.dump(medium_data)

large_json = JSON.generate(large_data)
large_marshal = Marshal.dump(large_data)

puts "\nData sizes:"
puts "Small - JSON: #{small_json.bytesize} bytes, Marshal: #{small_marshal.bytesize} bytes"
puts "Medium - JSON: #{medium_json.bytesize} bytes, Marshal: #{medium_marshal.bytesize} bytes"
puts "Large - JSON: #{large_json.bytesize} bytes, Marshal: #{large_marshal.bytesize} bytes"

puts "\n=== Small Data (#{small_data.keys.length} keys) ==="
Benchmark.bm(20) do |x|
  x.report("JSON.parse") do
    10000.times { JSON.parse(small_json) }
  end
  
  x.report("Marshal.load") do
    10000.times { Marshal.load(small_marshal) }
  end
end

puts "\n=== Medium Data (100 users + metadata) ==="
Benchmark.bm(20) do |x|
  x.report("JSON.parse") do
    1000.times { JSON.parse(medium_json) }
  end
  
  x.report("Marshal.load") do
    1000.times { Marshal.load(medium_marshal) }
  end
end

puts "\n=== Large Data (1000 posts with nested data) ==="
Benchmark.bm(20) do |x|
  x.report("JSON.parse") do
    100.times { JSON.parse(large_json) }
  end
  
  x.report("Marshal.load") do
    100.times { Marshal.load(large_marshal) }
  end
end

# Test serialization too for completeness
puts "\n=== Serialization Comparison (Medium Data) ==="
Benchmark.bm(20) do |x|
  x.report("JSON.generate") do
    1000.times { JSON.generate(medium_data) }
  end
  
  x.report("JSON.fast_generate") do
    1000.times { JSON.fast_generate(medium_data) }
  end
  
  x.report("Marshal.dump") do
    1000.times { Marshal.dump(medium_data) }
  end
end

puts "\n=== Memory Usage Analysis ==="
puts "Small data Marshal vs JSON ratio: #{small_marshal.bytesize.to_f / small_json.bytesize}"
puts "Medium data Marshal vs JSON ratio: #{medium_marshal.bytesize.to_f / medium_json.bytesize}"
puts "Large data Marshal vs JSON ratio: #{large_marshal.bytesize.to_f / large_json.bytesize}"

puts "\nNote: Marshal is Ruby-specific binary format, JSON is text-based universal format"