#!/usr/bin/env ruby

require 'benchmark'

# Test data
data = 100.times.map { |i| "item#{i}" }

puts "Testing different loop patterns for JSON array building (1000 iterations):"

Benchmark.bm(25) do |x|
  x.report("each_with_index") do
    1000.times do
      json = +"["
      data.each_with_index do |item, i|
        json << "," if i > 0
        json << "\"#{item}\""
      end
      json << "]"
    end
  end
  
  x.report("each + first flag") do
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
  
  x.report("manual counter") do
    1000.times do
      json = +"["
      i = 0
      data.each do |item|
        json << "," if i > 0
        json << "\"#{item}\""
        i += 1
      end
      json << "]"
    end
  end
  
  x.report("times loop") do
    1000.times do
      json = +"["
      data.length.times do |i|
        json << "," if i > 0
        json << "\"#{data[i]}\""
      end
      json << "]"
    end
  end
  
  x.report("while loop") do
    1000.times do
      json = +"["
      i = 0
      while i < data.length
        json << "," if i > 0
        json << "\"#{data[i]}\""
        i += 1
      end
      json << "]"
    end
  end
  
  x.report("for loop") do
    1000.times do
      json = +"["
      for i in 0...data.length
        json << "," if i > 0
        json << "\"#{data[i]}\""
      end
      json << "]"
    end
  end
  
  x.report("first + rest pattern") do
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
  
  x.report("map + join") do
    1000.times do
      items = data.map { |item| "\"#{item}\"" }
      json = "[#{items.join(',')}]"
    end
  end
  
  x.report("build parts array") do
    1000.times do
      parts = [+"["]
      data.each_with_index do |item, i|
        parts << "," if i > 0
        parts << "\"#{item}\""
      end
      parts << "]"
      json = parts.join
    end
  end
end