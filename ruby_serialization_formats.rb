#!/usr/bin/env ruby

require 'benchmark'
require 'json'
require 'yaml'
require 'csv'
require 'psych'  # Ruby's YAML implementation
require 'pp'     # Pretty print

puts "Ruby Data Representation Formats Benchmark (Ruby #{RUBY_VERSION}):"

# Test data
test_data = {
  "id" => 1,
  "name" => "Alice Johnson",
  "email" => "alice@example.com",
  "active" => true,
  "tags" => ["user", "premium", "verified"],
  "profile" => {
    "age" => 30,
    "city" => "San Francisco",
    "preferences" => {
      "theme" => "dark",
      "notifications" => true
    }
  },
  "scores" => [95.5, 87.2, 92.1],
  "created_at" => "2025-08-07T15:42:30Z"
}

puts "\nTest data structure:"
pp test_data

puts "\n" + "="*60

# 1. JSON
json_data = JSON.generate(test_data)
json_fast = JSON.fast_generate(test_data)
json_pretty = JSON.pretty_generate(test_data)

# 2. Marshal (Ruby binary)
marshal_data = Marshal.dump(test_data)

# 3. YAML
yaml_data = YAML.dump(test_data)
yaml_inline = test_data.to_yaml

# 4. Pretty Print (inspect-like)
pp_data = test_data.pretty_inspect

# 5. Inspect (Ruby code representation)
inspect_data = test_data.inspect

# 6. String interpolation / eval (dangerous but possible)
eval_string = test_data.inspect  # Same as inspect for this purpose

# 7. CSV (for flat/tabular data only - simulate with array)
flat_data = [test_data["id"], test_data["name"], test_data["email"], test_data["active"]]
csv_data = CSV.generate { |csv| csv << flat_data }

# 8. Custom formats
def to_custom_format(data, indent = 0)
  spaces = "  " * indent
  case data
  when Hash
    result = "{\n"
    data.each do |k, v|
      result << "#{spaces}  #{k}: #{to_custom_format(v, indent + 1)}\n"
    end
    result << "#{spaces}}"
  when Array
    "[" + data.map { |item| to_custom_format(item, indent) }.join(", ") + "]"
  when String
    "\"#{data}\""
  else
    data.inspect
  end
end

custom_data = to_custom_format(test_data)

puts "Data size comparison:"
puts "JSON:           #{json_data.bytesize} bytes"
puts "JSON (pretty):  #{json_pretty.bytesize} bytes"
puts "Marshal:        #{marshal_data.bytesize} bytes"
puts "YAML:           #{yaml_data.bytesize} bytes"
puts "Pretty Print:   #{pp_data.bytesize} bytes"
puts "Inspect:        #{inspect_data.bytesize} bytes"
puts "CSV (flat):     #{csv_data.bytesize} bytes"
puts "Custom:         #{custom_data.bytesize} bytes"

puts "\n" + "="*60
puts "SERIALIZATION Performance (1000 iterations):"

Benchmark.bm(20) do |x|
  x.report("JSON.generate") do
    1000.times { JSON.generate(test_data) }
  end
  
  x.report("JSON.fast_generate") do
    1000.times { JSON.fast_generate(test_data) }
  end
  
  x.report("Marshal.dump") do
    1000.times { Marshal.dump(test_data) }
  end
  
  x.report("YAML.dump") do
    1000.times { YAML.dump(test_data) }
  end
  
  x.report("to_yaml") do
    1000.times { test_data.to_yaml }
  end
  
  x.report("inspect") do
    1000.times { test_data.inspect }
  end
  
  x.report("pretty_inspect") do
    1000.times { test_data.pretty_inspect }
  end
  
  x.report("Custom format") do
    1000.times { to_custom_format(test_data) }
  end
end

puts "\n" + "="*60
puts "DESERIALIZATION Performance (1000 iterations):"

Benchmark.bm(20) do |x|
  x.report("JSON.parse") do
    1000.times { JSON.parse(json_data) }
  end
  
  x.report("Marshal.load") do
    1000.times { Marshal.load(marshal_data) }
  end
  
  x.report("YAML.load") do
    1000.times { YAML.load(yaml_data) }
  end
  
  x.report("YAML.safe_load") do
    1000.times { YAML.safe_load(yaml_data) }
  end
  
  x.report("eval (DANGEROUS)") do
    1000.times { eval(eval_string) }
  end
end

puts "\n" + "="*60
puts "Sample outputs:"

puts "\n1. JSON:"
puts json_data[0..100] + "..."

puts "\n2. JSON Pretty:"
puts json_pretty.lines[0..3].join

puts "\n3. Marshal (binary - showing first 20 bytes as hex):"
puts marshal_data[0..20].unpack('H*').first

puts "\n4. YAML:"
puts yaml_data.lines[0..5].join

puts "\n5. Pretty Print:"
puts pp_data.lines[0..3].join

puts "\n6. Inspect:"
puts inspect_data[0..100] + "..."

puts "\n7. CSV (flattened data):"
puts csv_data

puts "\n8. Custom Format:"
puts custom_data.lines[0..5].join

puts "\n" + "="*60
puts "Special Ruby formats:"

# MessagePack (if available)
begin
  require 'msgpack'
  msgpack_data = test_data.to_msgpack
  puts "MessagePack: #{msgpack_data.bytesize} bytes (requires gem)"
  
  Benchmark.bm(20) do |x|
    x.report("MessagePack.pack") do
      1000.times { test_data.to_msgpack }
    end
    
    x.report("MessagePack.unpack") do
      1000.times { MessagePack.unpack(msgpack_data) }
    end
  end
rescue LoadError
  puts "MessagePack: Not installed (gem install msgpack)"
end

# Oj (if available) 
begin
  require 'oj'
  oj_data = Oj.dump(test_data)
  puts "Oj: #{oj_data.bytesize} bytes (requires gem)"
  
  Benchmark.bm(20) do |x|
    x.report("Oj.dump") do
      1000.times { Oj.dump(test_data) }
    end
    
    x.report("Oj.load") do
      1000.times { Oj.load(oj_data) }
    end
  end
rescue LoadError
  puts "Oj: Not installed (gem install oj)"
end

puts "\n" + "="*60
puts "Summary of Ruby data representation formats:"
puts "1. JSON - Universal, fast, text-based"
puts "2. Marshal - Ruby-specific, binary, preserves Ruby objects"
puts "3. YAML - Human-readable, slower, preserves types"
puts "4. CSV - Tabular data only, very compact for flat data"
puts "5. Pretty Print - Debug-friendly, not for storage"
puts "6. Inspect - Ruby code representation, eval-able but dangerous"
puts "7. Custom formats - Domain-specific optimizations"
puts "8. MessagePack - Binary, cross-language, very fast (gem)"
puts "9. Oj - Optimized JSON, fastest JSON parser (gem)"
puts "10. String interpolation - Custom text formats"