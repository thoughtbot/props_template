#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'

# Test data
data = 100.times.map { |i| "item#{i}" }

puts "Optimized Array Building Benchmark (Ruby #{RUBY_VERSION}):"

Benchmark.bm(35) do |x|
  x.report("Oj::StringWriter") do
    1000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_array
      data.each { |item| stream.push_value(item) }
      stream.pop
      stream.raw_json
    end
  end
  
  x.report("String: first+rest (original)") do
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
  
  x.report("String: boolean flag") do
    1000.times do
      json = +"["
      first = true
      data.each do |item|
        if first
          first = false
        else
          json << ","
        end
        json << "\"#{item}\""
      end
      json << "]"
    end
  end
  
  x.report("String: counter approach") do
    1000.times do
      json = +"["
      data.each_with_index do |item, i|
        json << "," if i > 0
        json << '"' << item << '"'  # No interpolation
      end
      json << "]"
    end
  end
  
  x.report("String: manual loop") do
    1000.times do
      json = +"["
      i = 0
      while i < data.length
        json << "," if i > 0
        json << '"' << data[i] << '"'
        i += 1
      end
      json << "]"
    end
  end
  
  x.report("String: times loop") do
    1000.times do
      json = +"["
      data.length.times do |i|
        json << "," if i > 0
        json << '"' << data[i] << '"'
      end
      json << "]"
    end
  end
  
  x.report("String: no interpolation") do
    1000.times do
      json = +"["
      first = true
      data.each do |item|
        if first
          first = false
        else
          json << ","
        end
        json << '"' << item.to_s << '"'
      end
      json << "]"
    end
  end
  
  x.report("Array map + join") do
    1000.times do
      quoted = data.map { |item| "\"#{item}\"" }
      json = "[#{quoted.join(',')}]"
    end
  end
  
  x.report("Array map + join (no interpolation)") do
    1000.times do
      quoted = data.map { |item| '"' + item.to_s + '"' }
      json = "[#{quoted.join(',')}]"
    end
  end
  
  x.report("String: format approach") do
    1000.times do
      parts = []
      data.each { |item| parts << "\"#{item}\"" }
      json = "[#{parts.join(',')}]"
    end
  end
  
  x.report("String: direct build") do
    1000.times do
      json = +"[\""
      json << data[0] if data[0]
      data[1..-1]&.each do |item|
        json << '","' << item
      end
      json << "\"]"
    end
  end
end

puts "\nTesting what Oj is actually doing internally..."

# Let's see what the actual JSON looks like
stream = Oj::StringWriter.new(mode: :rails)
stream.push_array
["test1", "test2", "test3"].each { |item| stream.push_value(item) }
stream.pop
oj_result = stream.raw_json

string_result = '["test1","test2","test3"]'

puts "Oj result:    #{oj_result}"
puts "String result: #{string_result}" 
puts "Equal? #{oj_result == string_result}"

puts "\nTesting individual push_value vs string building:"

Benchmark.bm(25) do |x|
  x.report("Oj push_value loop") do
    10000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_value("test_string")
      stream.raw_json
    end
  end
  
  x.report("String interpolation") do
    10000.times do
      json = "\"test_string\""
    end
  end
  
  x.report("String concatenation") do
    10000.times do
      json = '"' + "test_string" + '"'
    end
  end
  
  x.report("String << approach") do
    10000.times do
      json = +""
      json << '"' << "test_string" << '"'
    end
  end
end