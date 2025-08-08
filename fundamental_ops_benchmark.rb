#!/usr/bin/env ruby

require 'benchmark'
require 'json'

puts "Fundamental Ruby Operations Benchmark (Ruby #{RUBY_VERSION}):"

# Test data
data = { id: 1, name: "Alice", email: "alice@example.com" }
array_data = [1, 2, 3, 4, 5]
string_data = "hello world"

puts "\n=== String Building Operations ==="
Benchmark.bm(25) do |x|
  x.report("String interpolation") do
    100000.times do
      result = "#{data[:id]},#{data[:name]},#{data[:email]}"
    end
  end
  
  x.report("String concatenation") do
    100000.times do
      result = data[:id].to_s + "," + data[:name] + "," + data[:email]
    end
  end
  
  x.report("String << operator") do
    100000.times do
      result = +""
      result << data[:id].to_s << "," << data[:name] << "," << data[:email]
    end
  end
  
  x.report("Array join") do
    100000.times do
      result = [data[:id], data[:name], data[:email]].join(",")
    end
  end
  
  x.report("sprintf/format") do
    100000.times do
      result = sprintf("%s,%s,%s", data[:id], data[:name], data[:email])
    end
  end
end

puts "\n=== Hash Building Operations ==="
Benchmark.bm(25) do |x|
  x.report("Hash literal") do
    100000.times do
      result = { id: data[:id], name: data[:name], email: data[:email] }
    end
  end
  
  x.report("Hash[]") do
    100000.times do
      result = Hash[:id, data[:id], :name, data[:name], :email, data[:email]]
    end
  end
  
  x.report("Hash assignment") do
    100000.times do
      result = {}
      result[:id] = data[:id]
      result[:name] = data[:name]
      result[:email] = data[:email]
    end
  end
  
  x.report("Hash merge") do
    100000.times do
      result = {}.merge(id: data[:id], name: data[:name], email: data[:email])
    end
  end
end

puts "\n=== Array Building Operations ==="
Benchmark.bm(25) do |x|
  x.report("Array literal") do
    100000.times do
      result = [data[:id], data[:name], data[:email]]
    end
  end
  
  x.report("Array.new + push") do
    100000.times do
      result = Array.new
      result.push(data[:id])
      result.push(data[:name]) 
      result.push(data[:email])
    end
  end
  
  x.report("Array << operator") do
    100000.times do
      result = []
      result << data[:id] << data[:name] << data[:email]
    end
  end
  
  x.report("Array + operator") do
    100000.times do
      result = [data[:id]] + [data[:name]] + [data[:email]]
    end
  end
end

puts "\n=== JSON Serialization Operations ==="
hash_result = { id: data[:id], name: data[:name], email: data[:email] }
array_result = [data[:id], data[:name], data[:email]]

Benchmark.bm(25) do |x|
  x.report("JSON.generate hash") do
    10000.times do
      result = JSON.generate(hash_result)
    end
  end
  
  x.report("JSON.generate array") do
    10000.times do
      result = JSON.generate(array_result)
    end
  end
  
  x.report("JSON.fast_generate") do
    10000.times do
      result = JSON.fast_generate(hash_result)
    end
  end
  
  x.report("to_json method") do
    10000.times do
      result = hash_result.to_json
    end
  end
end

puts "\n=== Loop Operations ==="
test_array = (1..100).to_a

Benchmark.bm(25) do |x|
  x.report("each") do
    1000.times do
      result = []
      test_array.each { |item| result << item * 2 }
    end
  end
  
  x.report("map") do
    1000.times do
      result = test_array.map { |item| item * 2 }
    end
  end
  
  x.report("for loop") do
    1000.times do
      result = []
      for item in test_array
        result << item * 2
      end
    end
  end
  
  x.report("while loop") do
    1000.times do
      result = []
      i = 0
      while i < test_array.length
        result << test_array[i] * 2
        i += 1
      end
    end
  end
  
  x.report("times loop") do
    1000.times do
      result = []
      test_array.length.times do |i|
        result << test_array[i] * 2
      end
    end
  end
end

puts "\n=== Memory Operations ==="
Benchmark.bm(25) do |x|
  x.report("String.new") do
    100000.times do
      result = String.new
    end
  end
  
  x.report("Empty string +\"\"") do
    100000.times do
      result = +""
    end
  end
  
  x.report("Empty string \"\"") do
    100000.times do
      result = ""
    end
  end
  
  x.report("Hash.new") do
    100000.times do
      result = Hash.new
    end
  end
  
  x.report("Empty hash {}") do
    100000.times do
      result = {}
    end
  end
  
  x.report("Array.new") do
    100000.times do
      result = Array.new
    end
  end
  
  x.report("Empty array []") do
    100000.times do
      result = []
    end
  end
end