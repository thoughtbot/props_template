#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'oj'
require 'json'

puts "Hash Building vs Stream Building Benchmark (Ruby #{RUBY_VERSION}):"

# Test data - simulate a realistic props template scenario
users = 50.times.map do |i|
  {
    id: i,
    name: "User #{i}",
    email: "user#{i}@example.com",
    active: i.even?,
    posts_count: rand(10),
    last_login: Time.now - rand(30) * 86400,
    profile: {
      bio: "Bio for user #{i}",
      location: "City #{i % 5}",
      preferences: { theme: "dark", lang: "en" }
    }
  }
end

posts = 100.times.map do |i|
  {
    id: i,
    title: "Post #{i}",
    body: "This is the body of post #{i}. " * 5, # Make it realistic size
    author_id: i % 50,
    published: i.even?,
    tags: ["tag#{i % 10}", "tag#{(i+1) % 10}"],
    comments_count: rand(20)
  }
end

Benchmark.bm(35) do |x|
  x.report("Oj::StringWriter streaming") do
    100.times do
      stream = Oj::StringWriter.new(mode: :rails)
      
      stream.push_object
      
      # Users section
      stream.push_key("users")
      stream.push_array
      users.each do |user|
        stream.push_object
        stream.push_value(user[:id], "id")
        stream.push_value(user[:name], "name")
        stream.push_value(user[:email], "email")
        stream.push_value(user[:active], "active")
        stream.push_value(user[:posts_count], "posts_count")
        stream.push_value(user[:last_login].iso8601, "last_login")
        
        # Nested profile
        stream.push_key("profile")
        stream.push_object
        stream.push_value(user[:profile][:bio], "bio")
        stream.push_value(user[:profile][:location], "location")
        stream.push_key("preferences")
        stream.push_object
        stream.push_value(user[:profile][:preferences][:theme], "theme")
        stream.push_value(user[:profile][:preferences][:lang], "lang")
        stream.pop # preferences
        stream.pop # profile
        
        stream.pop # user
      end
      stream.pop # users array
      
      # Posts section
      stream.push_key("posts")
      stream.push_array
      posts.each do |post|
        stream.push_object
        stream.push_value(post[:id], "id")
        stream.push_value(post[:title], "title")
        stream.push_value(post[:body], "body")
        stream.push_value(post[:author_id], "author_id")
        stream.push_value(post[:published], "published")
        stream.push_value(post[:comments_count], "comments_count")
        
        # Tags array
        stream.push_key("tags")
        stream.push_array
        post[:tags].each { |tag| stream.push_value(tag) }
        stream.pop # tags
        
        stream.pop # post
      end
      stream.pop # posts array
      
      stream.push_value("success", "status")
      stream.push_value(Time.now.iso8601, "generated_at")
      
      stream.pop # root object
      result = stream.raw_json
    end
  end
  
  x.report("Hash build + JSON.generate") do
    100.times do
      result_hash = {}
      
      # Users section
      result_hash[:users] = users.map do |user|
        {
          id: user[:id],
          name: user[:name],
          email: user[:email],
          active: user[:active],
          posts_count: user[:posts_count],
          last_login: user[:last_login].iso8601,
          profile: {
            bio: user[:profile][:bio],
            location: user[:profile][:location],
            preferences: {
              theme: user[:profile][:preferences][:theme],
              lang: user[:profile][:preferences][:lang]
            }
          }
        }
      end
      
      # Posts section
      result_hash[:posts] = posts.map do |post|
        {
          id: post[:id],
          title: post[:title],
          body: post[:body],
          author_id: post[:author_id],
          published: post[:published],
          comments_count: post[:comments_count],
          tags: post[:tags]
        }
      end
      
      result_hash[:status] = "success"
      result_hash[:generated_at] = Time.now.iso8601
      
      json = JSON.generate(result_hash)
    end
  end
  
  x.report("Hash build + Oj.dump") do
    100.times do
      result_hash = {}
      
      # Users section (same as above)
      result_hash[:users] = users.map do |user|
        {
          id: user[:id],
          name: user[:name],
          email: user[:email],
          active: user[:active],
          posts_count: user[:posts_count],
          last_login: user[:last_login].iso8601,
          profile: {
            bio: user[:profile][:bio],
            location: user[:profile][:location],
            preferences: {
              theme: user[:profile][:preferences][:theme],
              lang: user[:profile][:preferences][:lang]
            }
          }
        }
      end
      
      # Posts section (same as above)
      result_hash[:posts] = posts.map do |post|
        {
          id: post[:id],
          title: post[:title],
          body: post[:body],
          author_id: post[:author_id],
          published: post[:published],
          comments_count: post[:comments_count],
          tags: post[:tags]
        }
      end
      
      result_hash[:status] = "success"
      result_hash[:generated_at] = Time.now.iso8601
      
      json = Oj.dump(result_hash, mode: :rails)
    end
  end
  
  x.report("String concatenation approach") do
    100.times do
      json = +'{"users":['
      
      users.each_with_index do |user, i|
        json << "," if i > 0
        json << '{"id":' << user[:id].to_s <<
               ',"name":"' << user[:name] <<
               '","email":"' << user[:email] <<
               '","active":' << user[:active].to_s <<
               ',"posts_count":' << user[:posts_count].to_s <<
               ',"last_login":"' << user[:last_login].iso8601 <<
               '","profile":{"bio":"' << user[:profile][:bio] <<
               '","location":"' << user[:profile][:location] <<
               '","preferences":{"theme":"' << user[:profile][:preferences][:theme] <<
               '","lang":"' << user[:profile][:preferences][:lang] << '"}}}'
      end
      
      json << '],"posts":['
      
      posts.each_with_index do |post, i|
        json << "," if i > 0
        json << '{"id":' << post[:id].to_s <<
               ',"title":"' << post[:title] <<
               '","body":"' << post[:body] <<
               '","author_id":' << post[:author_id].to_s <<
               ',"published":' << post[:published].to_s <<
               ',"comments_count":' << post[:comments_count].to_s <<
               ',"tags":["' << post[:tags].join('","') << '"]}'
      end
      
      json << '],"status":"success","generated_at":"' << Time.now.iso8601 << '"}'
    end
  end
  
  x.report("Hybrid: Hash + String injection") do
    100.times do
      # Build complex nested data as hashes
      users_hash = users.map do |user|
        {
          id: user[:id],
          name: user[:name],
          email: user[:email],
          active: user[:active],
          posts_count: user[:posts_count],
          last_login: user[:last_login].iso8601,
          profile: {
            bio: user[:profile][:bio],
            location: user[:profile][:location],
            preferences: {
              theme: user[:profile][:preferences][:theme],
              lang: user[:profile][:preferences][:lang]
            }
          }
        }
      end
      
      posts_hash = posts.map do |post|
        {
          id: post[:id],
          title: post[:title],
          body: post[:body],
          author_id: post[:author_id],
          published: post[:published],
          comments_count: post[:comments_count],
          tags: post[:tags]
        }
      end
      
      # Convert to JSON separately
      users_json = JSON.generate(users_hash)
      posts_json = JSON.generate(posts_hash)
      
      # Inject into final structure
      json = '{"users":' + users_json + 
             ',"posts":' + posts_json + 
             ',"status":"success","generated_at":"' + Time.now.iso8601 + '"}'
    end
  end
end

puts "\nMemory allocation comparison:"
require 'objspace'

GC.start
GC.disable

before = ObjectSpace.count_objects

# Test Oj streaming
10.times do
  stream = Oj::StringWriter.new(mode: :rails)
  stream.push_object
  stream.push_key("test")
  stream.push_array
  users.first(5).each do |user|
    stream.push_object
    stream.push_value(user[:id], "id")
    stream.push_value(user[:name], "name")
    stream.pop
  end
  stream.pop
  stream.pop
  result = stream.raw_json
end

after_oj = ObjectSpace.count_objects

# Test hash building
10.times do
  result_hash = {
    test: users.first(5).map do |user|
      { id: user[:id], name: user[:name] }
    end
  }
  json = JSON.generate(result_hash)
end

after_hash = ObjectSpace.count_objects

GC.enable

puts "Oj streaming allocations: #{after_oj[:TOTAL] - before[:TOTAL]}"
puts "Hash building allocations: #{after_hash[:TOTAL] - after_oj[:TOTAL]}"

puts "\nOutput size comparison:"
# Generate one result from each approach to compare
stream = Oj::StringWriter.new(mode: :rails)
stream.push_object
stream.push_key("users")
stream.push_array
users.first(3).each do |user|
  stream.push_object
  stream.push_value(user[:id], "id")
  stream.push_value(user[:name], "name")
  stream.pop
end
stream.pop
stream.pop
oj_result = stream.raw_json

hash_result = JSON.generate({
  users: users.first(3).map { |user| { id: user[:id], name: user[:name] } }
})

puts "Oj result size: #{oj_result.bytesize} bytes"
puts "Hash result size: #{hash_result.bytesize} bytes"
puts "Results identical: #{oj_result == hash_result}"