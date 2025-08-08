#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'
require 'json'

# Test different scenarios
def test_simple_object
  puts "\n=== Simple Object Test (1000 iterations) ==="
  
  Benchmark.bm(20) do |x|
    x.report("Oj::StringWriter") do
      1000.times do
        stream = Oj::StringWriter.new(mode: :rails)
        stream.push_object
        stream.push_value("John Doe", "name")
        stream.push_value(42, "age") 
        stream.push_value(true, "active")
        stream.pop
        stream.raw_json
      end
    end
    
    x.report("String concat") do
      1000.times do
        json = +""
        json << '{'
        json << '"name":"John Doe",'
        json << '"age":42,'
        json << '"active":true'
        json << '}'
      end
    end
    
    x.report("String interpolation") do
      1000.times do
        name, age, active = "John Doe", 42, true
        json = "{\"name\":\"#{name}\",\"age\":#{age},\"active\":#{active}}"
      end
    end
  end
end

def test_array_building
  puts "\n=== Array Building Test (100 items, 1000 iterations) ==="
  
  data = 100.times.map { |i| "item#{i}" }
  
  Benchmark.bm(20) do |x|
    x.report("Oj::StringWriter") do
      1000.times do
        stream = Oj::StringWriter.new(mode: :rails)
        stream.push_array
        data.each { |item| stream.push_value(item) }
        stream.pop
        stream.raw_json
      end
    end
    
    x.report("String concat") do
      1000.times do
        json = +"["
        unless data.empty?
          json << "\"#{data[0]}\""
          data[1..-1].each do |item|
            json << ",\"#{item}\""
          end
        end
        json << "]"
      end
    end
    
    x.report("Array join") do
      1000.times do
        items = data.map { |item| "\"#{item}\"" }
        json = "[#{items.join(',')}]"
      end
    end
  end
end

def test_escaping_overhead
  puts "\n=== Escaping Overhead Test (strings with quotes) ==="
  
  tricky_strings = [
    'John "Johnny" Doe',
    'Path: C:\\Users\\John',
    "Multi\nLine\nString", 
    'Special chars: <script>alert("xss")</script>'
  ]
  
  Benchmark.bm(20) do |x|
    x.report("Oj::StringWriter") do
      10000.times do
        stream = Oj::StringWriter.new(mode: :rails)
        stream.push_object
        tricky_strings.each_with_index do |str, i|
          stream.push_value(str, "field#{i}")
        end
        stream.pop
        stream.raw_json
      end
    end
    
    x.report("Manual escaping") do
      10000.times do
        json = +"{"
        tricky_strings.each_with_index do |str, i|
          json << "," if i > 0
          escaped = str.gsub('"', '\\"').gsub('\\', '\\\\').gsub("\n", '\\n')
          json << "\"field#{i}\":\"#{escaped}\""
        end
        json << "}"
      end
    end
    
    x.report("JSON.generate") do
      10000.times do
        hash = {}
        tricky_strings.each_with_index do |str, i|
          hash["field#{i}"] = str
        end
        JSON.generate(hash)
      end
    end
  end
end

def test_caching_simulation
  puts "\n=== Cached Fragment Simulation (Realistic) ==="
  
  # Simulate what's actually cached - marshaled Ruby objects
  cached_object = {
    expensive: "computation", 
    data: [1,2,3,4,5],
    timestamp: "2023-12-07T10:30:00Z",
    nested: {
      user: { name: "John", posts: [{ title: "Post 1" }, { title: "Post 2" }] },
      settings: { theme: "dark", notifications: true }
    }
  }
  
  # What other libraries cache
  marshaled_cache = Marshal.dump(cached_object)
  
  # What props template caches (pre-serialized JSON)
  json_cache = JSON.generate(cached_object)
  
  Benchmark.bm(30) do |x|
    x.report("Props template (Oj push_json)") do
      10000.times do
        stream = Oj::StringWriter.new(mode: :rails)
        stream.push_object
        stream.push_value("fresh_data", "status")
        stream.push_key("cached")
        stream.push_json(json_cache)  # Direct JSON injection
        stream.pop
        stream.raw_json
      end
    end
    
    x.report("Props template (String concat)") do
      10000.times do
        json = +"{"
        json << '"status":"fresh_data",'
        json << '"cached":'
        json << json_cache  # Direct JSON injection
        json << "}"
      end
    end
    
    x.report("Traditional (Marshal + merge)") do
      10000.times do
        fresh = { status: "fresh_data" }
        cached = Marshal.load(marshaled_cache)  # Unmarshal
        merged = fresh.merge(cached: cached)    # Hash merge
        JSON.generate(merged)                   # Full serialization
      end
    end
    
    x.report("Traditional (JSON parse + merge)") do
      10000.times do
        fresh = { status: "fresh_data" }
        cached = JSON.parse(json_cache)         # Parse JSON back to hash
        merged = fresh.merge(cached: cached)    # Hash merge  
        JSON.generate(merged)                   # Re-serialize
      end
    end
    
    x.report("Hybrid (build hash + generate)") do
      10000.times do
        # What you'd do without props template architecture
        result = {
          status: "fresh_data", 
          cached: cached_object  # Use original object
        }
        JSON.generate(result)
      end
    end
  end
end

def test_memory_pressure
  puts "\n=== Memory Pressure Test ==="
  
  require 'objspace'
  
  # Force GC and measure
  GC.start
  GC.disable
  
  before = ObjectSpace.count_objects
  
  1000.times do
    stream = Oj::StringWriter.new(mode: :rails)
    stream.push_object
    stream.push_value("test", "key")
    stream.pop
    result = stream.raw_json
  end
  
  after_oj = ObjectSpace.count_objects
  
  1000.times do
    json = +""
    json << '{"key":"test"}'
  end
  
  after_string = ObjectSpace.count_objects
  
  GC.enable
  
  puts "Oj objects created: #{after_oj[:TOTAL] - before[:TOTAL]}"
  puts "String objects created: #{after_string[:TOTAL] - after_oj[:TOTAL]}"
  puts "String objects are #{((after_string[:TOTAL] - after_oj[:TOTAL]).to_f / (after_oj[:TOTAL] - before[:TOTAL])).round(2)}x more"
end

# Run all tests
test_simple_object
test_array_building  
test_escaping_overhead
test_caching_simulation
test_memory_pressure