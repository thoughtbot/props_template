require "bundler/setup"
require "bundler/gem_tasks"
require "standard/rake"
require "fileutils"
require "rake/testtask"

task :performance do
  require "analyzer"

  base = File.expand_path("../performance/rolftimmermans", __FILE__)
  output_file = File.join(base, "report.png")
  files = [
    "props_template/oj.rb",
    "jbuilder/oj.rb",
    "rabl/oj.rb",
    "ams/oj.rb",
    "fast_jsonapi/oj.rb",
    "turbostreamer/oj.rb"
    # 'props_base/oj.rb',
    # 'poro/oj.rb',
    # 'just_oj/oj.rb',
  ].map { |i| File.join(base, i) }
  analyzer = Analyzer.new(*files, lib: File.join(base, "lib.rb"))
  analyzer.plot(output_file)

  base = File.expand_path("../performance/dirk", __FILE__)
  output_file = File.join(base, "report.png")
  files = [
    "props_template/oj.rb",
    "ams/oj.rb",
    "rabl/oj.rb",
    "jbuilder/oj.rb",
    "turbostreamer/oj.rb"
  ].map { |i| File.join(base, i) }
  analyzer = Analyzer.new(*files, lib: File.join(base, "lib.rb"))
  analyzer.plot(output_file)
end
