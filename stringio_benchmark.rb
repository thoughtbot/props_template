#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'
require 'json'
require 'stringio'

# Test data
data = 100.times.map { |i| "item#{i}" }

puts "Comparing String vs StringIO for JSON building (Ruby #{RUBY_VERSION}):"

Benchmark.bm(25) do |x|
  x.report("Oj::StringWriter") do
    1000.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_array
      data.each { |item| stream.push_value(item) }
      stream.pop
      stream.raw_json
    end
  end
  
  x.report("String concatenation") do
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
  
  x.report("StringIO") do
    1000.times do
      io = StringIO.new
      io << "["
      unless data.empty?
        io << "\"#{data[0]}\""
        data[1..-1].each do |item|
          io << ",\"#{item}\""
        end
      end
      io << "]"
      io.string
    end
  end
  
  x.report("StringIO pre-allocated") do
    1000.times do
      io = StringIO.new("", "w")
      io.string.force_encoding("UTF-8")  # Ensure proper encoding
      io << "["
      unless data.empty?
        io << "\"#{data[0]}\""
        data[1..-1].each do |item|
          io << ",\"#{item}\""
        end
      end
      io << "]"
      io.string
    end
  end
  
  x.report("StringIO with capacity") do
    1000.times do
      # Pre-allocate estimated size
      initial = String.new(capacity: 2000)
      io = StringIO.new(initial, "w")
      io << "["
      unless data.empty?
        io << "\"#{data[0]}\""
        data[1..-1].each do |item|
          io << ",\"#{item}\""
        end
      end
      io << "]"
      io.string
    end
  end
  
  x.report("Array join approach") do
    1000.times do
      parts = [+"["]
      unless data.empty?
        parts << "\"#{data[0]}\""
        data[1..-1].each do |item|
          parts << ",\"#{item}\""
        end
      end
      parts << "]"
      parts.join
    end
  end
end

puts "\nTesting complex object building:"

users = 50.times.map do |i|
  {
    id: i,
    name: "User #{i}",
    email: "user#{i}@example.com",
    active: i.even?
  }
end

Benchmark.bm(25) do |x|
  x.report("Oj::StringWriter complex") do
    100.times do
      stream = Oj::StringWriter.new(mode: :rails)
      stream.push_object
      stream.push_key("users")
      stream.push_array
      users.each do |user|
        stream.push_object
        stream.push_value(user[:id], "id")
        stream.push_value(user[:name], "name")
        stream.push_value(user[:email], "email")
        stream.push_value(user[:active], "active")
        stream.pop
      end
      stream.pop
      stream.pop
      stream.raw_json
    end
  end
  
  x.report("String concatenation complex") do
    100.times do
      json = +'{"users":['
      users.each_with_index do |user, i|
        json << "," if i > 0
        json << '{"id":' << user[:id].to_s << 
               ',"name":"' << user[:name] << 
               '","email":"' << user[:email] << 
               '","active":' << user[:active].to_s << '}'
      end
      json << ']}'
    end
  end
  
  x.report("StringIO complex") do
    100.times do
      io = StringIO.new
      io << '{"users":['
      users.each_with_index do |user, i|
        io << "," if i > 0
        io << '{"id":' << user[:id].to_s << 
             ',"name":"' << user[:name] << 
             '","email":"' << user[:email] << 
             '","active":' << user[:active].to_s << '}'
      end
      io << ']}'
      io.string
    end
  end
  
  x.report("StringIO with buffer") do
    100.times do
      buffer = String.new(capacity: 5000)
      io = StringIO.new(buffer, "w")
      io << '{"users":['
      users.each_with_index do |user, i|
        io << "," if i > 0
        io << '{"id":' << user[:id].to_s << 
             ',"name":"' << user[:name] << 
             '","email":"' << user[:email] << 
             '","active":' << user[:active].to_s << '}'
      end
      io << ']}'
      io.string
    end
  end
end

puts "\nMemory allocation test:"
require 'objspace'

GC.start
before = ObjectSpace.count_objects

100.times do
  json = +"test"
  json << "more"
  json << "data"
end

after_string = ObjectSpace.count_objects

100.times do
  io = StringIO.new
  io << "test"
  io << "more"  
  io << "data"
  io.string
end

after_stringio = ObjectSpace.count_objects

puts "String objects: #{after_string[:TOTAL] - before[:TOTAL]}"
puts "StringIO objects: #{after_stringio[:TOTAL] - after_string[:TOTAL]}"