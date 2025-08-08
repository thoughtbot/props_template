#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'

# Test data
data = 100.times.map { |i| "item#{i}" }

puts "Direct String vs Oj Head-to-Head (Ruby #{RUBY_VERSION}):"

Benchmark.bm(40) do |x|
  x.report("Oj::StringWriter (baseline)") do
    1000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_array
      data.each { |item| stream.push_value(item) }
      stream.pop
      stream.raw_json
    end
  end
  
  x.report("String: direct build (original)") do
    1000.times do
      json = +"[\""
      json << data[0] if data[0]
      data[1..-1]&.each do |item|
        json << '","' << item
      end
      json << "\"]"
    end
  end
  
  x.report("String: pre-allocated buffer") do
    1000.times do
      # Pre-allocate estimated size: 100 items * ~10 chars each + overhead
      json = String.new(capacity: 1500)
      json << "[\""
      json << data[0] if data[0]
      data[1..-1]&.each do |item|
        json << '","' << item
      end
      json << "\"]"
    end
  end
  
  x.report("String: avoid safe navigation") do
    1000.times do
      json = +"[\""
      if data[0]
        json << data[0]
        (1...data.length).each do |i|
          json << '","' << data[i]
        end
      end
      json << "\"]"
    end
  end
  
  x.report("String: minimize method calls") do
    1000.times do
      json = +"["
      if data.length > 0
        json << "\"#{data[0]}\""
        i = 1
        while i < data.length
          json << ",\"#{data[i]}\""
          i += 1
        end
      end
      json << "]"
    end
  end
  
  x.report("String: single concatenation") do
    1000.times do
      parts = [+"["]
      if data.length > 0
        parts << "\"#{data[0]}\""
        (1...data.length).each do |i|
          parts << ",\"#{data[i]}\""
        end
      end
      parts << "]"
      json = parts.join
    end
  end
  
  x.report("String: frozen string optimization") do
    1000.times do
      json = +""
      json << "["
      if data.length > 0
        json << "\""
        json << data[0]
        json << "\""
        (1...data.length).each do |i|
          json << ",\""
          json << data[i]
          json << "\""
        end
      end
      json << "]"
    end
  end
  
  x.report("String: chunk building") do
    1000.times do
      if data.empty?
        json = "[]"
      else
        # Build in chunks to minimize string operations
        chunks = []
        chunks << "[\""
        chunks << data[0]
        
        # Build middle section in one go
        middle = (1...data.length).map { |i| "\",\"#{data[i]}" }.join
        chunks << middle if middle.length > 0
        
        chunks << "\"]"
        json = chunks.join
      end
    end
  end
  
  x.report("String: format string approach") do
    1000.times do
      if data.empty?
        json = "[]"
      else
        quoted_items = data.map { |item| "\"#{item}\"" }
        json = "[#{quoted_items.join(',')}]"
      end
    end
  end
  
  x.report("String: ultra-optimized") do
    1000.times do
      # Pre-allocate with exact size calculation
      estimated_size = 2 + (data.length * 8) + data.sum(&:length)
      json = String.new(capacity: estimated_size)
      
      json << "["
      data.each_with_index do |item, i|
        json << "," if i > 0
        json << "\""
        json << item
        json << "\""
      end
      json << "]"
    end
  end
end

puts "\nTesting the results are equivalent:"
# Oj result
stream = Oj::StringWriter.new(mode: :rails)
stream.push_array
["a", "b", "c"].each { |item| stream.push_value(item) }
stream.pop
oj_result = stream.raw_json

# String result  
test_data = ["a", "b", "c"]
json = +"[\""
json << test_data[0] if test_data[0]
test_data[1..-1]&.each do |item|
  json << '","' << item
end
json << "\"]"

puts "Oj result:     #{oj_result}"
puts "String result: #{json}"
puts "Equal?         #{oj_result == json}"

puts "\nAnalyzing what makes them different..."
puts "Oj result bytes:     #{oj_result.bytes}"
puts "String result bytes: #{json.bytes}"

# Test with more data
puts "\nMemory allocation analysis:"
require 'objspace'

GC.start
GC.disable

before = ObjectSpace.count_objects

# Test string approach
100.times do
  json = +"[\""
  json << data[0] if data[0]
  data[1..-1]&.each do |item|
    json << '","' << item
  end  
  json << "\"]"
end

after_string = ObjectSpace.count_objects

# Test Oj approach  
100.times do
  stream = Oj::StringWriter.new(mode: :rails)
  stream.push_array
  data.each { |item| stream.push_value(item) }
  stream.pop
  result = stream.raw_json
end

after_oj = ObjectSpace.count_objects

GC.enable

puts "String allocations: #{after_string[:TOTAL] - before[:TOTAL]}"
puts "Oj allocations: #{after_oj[:TOTAL] - after_string[:TOTAL]}"