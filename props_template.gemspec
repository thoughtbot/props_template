$LOAD_PATH << File.expand_path("lib", __dir__)
require "props_template/version"

Gem::Specification.new do |s|
  s.name     = 'props_template'
  s.version  = Props::VERSION
  s.author   = 'Johny Ho'
  s.email    = 'johny@thoughtbot.com'
  s.license  = 'MIT'
  s.homepage = 'https://github.com/thoughtbot/props_template/'
  s.summary  = 'A fast JSON builder'
  s.description = 'PropsTemplate is a direct-to-Oj, JBuilder-like DSL for building JSON. It has support for Russian-Doll caching, layouts, and can be queried by giving the root a key path.'
  s.files    =   Dir['MIT-LICENSE', 'README.md', 'lib/**/*']
  s.test_files = Dir["spec/*"]

  s.required_ruby_version = '>= 2.7'

  s.add_dependency 'activesupport', '>= 6.0.0'
  s.add_dependency 'actionview', '>= 6.0.0'
  s.add_dependency 'oj', '>= 3.9'
end
