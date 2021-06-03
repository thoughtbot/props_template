version = File.read(File.expand_path("./VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.name     = 'props_template'
  s.version  = version
  s.author   = 'Johny Ho'
  s.email    = 'johny@thoughtbot.com'
  s.license  = 'MIT'
  s.homepage = 'https://github.com/thoughtbot/props_template/'
  s.summary  = 'A fast JSON builder'
  s.description = 'A fast JSON builder'
  s.files    =   Dir['MIT-LICENSE', 'README.md', 'lib/**/*']
  s.test_files = Dir["spec/*"]

  s.required_ruby_version = '>= 2.5'

  s.add_dependency 'activesupport', '>= 6.0.0'
  s.add_dependency 'actionview', '>= 6.0.0'
  s.add_dependency 'oj', '>= 3.9'
end
