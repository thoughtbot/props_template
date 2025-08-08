#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'

# Test data
data = 100.times.map { |i| "item#{i}" }

puts "Extreme String Optimizations vs Oj (Ruby #{RUBY_VERSION}):"

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
  
  x.report("String: exact size calculation") do
    1000.times do
      # Calculate exact size needed
      total_chars = data.sum(&:length)
      # Format: ["item0","item1",...] = 2 brackets + (n-1) commas + n*2 quotes + content
      exact_size = 2 + (data.length - 1) + (data.length * 2) + total_chars
      
      json = String.new(capacity: exact_size)
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
  
  x.report("String: single string interpolation") do
    1000.times do
      if data.empty?
        json = "[]"
      else
        # Build the entire middle section in one interpolation
        middle = data.map { |item| "\"#{item}\"" }.join(",")
        json = "[#{middle}]"
      end
    end
  end
  
  x.report("String: pure concatenation only") do
    1000.times do
      json = +"["
      first = true
      data.each do |item|
        json << "," unless first
        first = false
        json << "\""
        json << item
        json << "\""
      end
      json << "]"
    end
  end
  
  x.report("String: unrolled first item") do
    1000.times do
      case data.length
      when 0
        json = "[]"
      when 1
        json = "[\"#{data[0]}\"]"
      else
        json = +"[\"#{data[0]}\""
        (1...data.length).each do |i|
          json << ",\"#{data[i]}\""
        end
        json << "]"
      end
    end
  end
  
  x.report("String: batch operations") do
    1000.times do
      if data.empty?
        json = "[]"
      else
        # Do all quotes in one operation, all commas in another
        parts = []
        parts << "["
        data.each_with_index do |item, i|
          parts << "," if i > 0
          parts << "\""
          parts << item  
          parts << "\""
        end
        parts << "]"
        json = parts.join
      end
    end
  end
  
  x.report("String: minimize object creation") do
    1000.times do
      # Use frozen strings and minimize allocations
      json = String.new(capacity: 1000)
      json << "["
      
      data.each_with_index do |item, i|
        json << "," if i > 0
        json << '"'
        json << item
        json << '"'
      end
      
      json << "]"
    end
  end
  
  x.report("String: C-style approach") do
    1000.times do
      # Simulate what C would do - minimal operations
      buffer = String.new(capacity: 2000)
      buffer << "["
      
      i = 0
      len = data.length
      while i < len
        buffer << "," if i > 0
        buffer << '"' + data[i] + '"'
        i += 1
      end
      
      buffer << "]"
    end
  end
end

# Let's also test what happens if we cache the StringWriter
puts "\nTesting StringWriter reuse:"

Benchmark.bm(40) do |x|
  x.report("Oj: new StringWriter each time") do
    1000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_array
      data.each { |item| stream.push_value(item) }
      stream.pop
      stream.raw_json
    end
  end
  
  x.report("Oj: reuse StringWriter") do
    stream = Oj::StringWriter.new(mode: :rails)
    1000.times do
      stream.push_array
      data.each { |item| stream.push_value(item) }
      stream.pop
      result = stream.raw_json
      # Note: StringWriter should reset after raw_json
    end
  end
  
  # Test if the StringWriter actually resets
  stream = Oj::StringWriter.new(mode: :rails)
  stream.push_value("test1")
  result1 = stream.raw_json
  
  stream.push_value("test2")  
  result2 = stream.raw_json
  
  puts "\nStringWriter reset test:"
  puts "First result:  #{result1}"
  puts "Second result: #{result2}"
  puts "Resets properly? #{result2 == '\"test2\"'}"
end

puts "\nFinding the bottleneck - what's the theoretical minimum?"

Benchmark.bm(30) do |x|
  x.report("Just string creation") do
    1000.times do
      json = String.new(capacity: 1000)
    end
  end
  
  x.report("String + one append") do  
    1000.times do
      json = String.new(capacity: 1000)
      json << "["
    end
  end
  
  x.report("String + 100 appends") do
    1000.times do
      json = String.new(capacity: 1000)
      100.times { json << "x" }
    end
  end
  
  x.report("Oj: just creation") do
    1000.times do
      stream = Oj::StringWriter.new(mode: :rails)
    end
  end
  
  x.report("Oj: creation + result") do
    1000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.raw_json
    end
  end
end