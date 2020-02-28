# encoding: utf-8

$: << File.expand_path('../lib', __FILE__)

Gem::Specification.new do |s|
  s.name          = 'cassandra-web'
  s.version       = '0.5.0'
  s.authors       = ['Bulat Shakirzyanov']
  s.email         = ['bulat.shakirzyanov@datastax.com']
  s.homepage      = 'https://github.com/avalanche123/cassandra-web'
  s.summary       = %q{A simple web ui for Apache Cassandra}
  s.description   = %q{Apache Cassandra web interface using Ruby, Event-machine, AngularJS, Server-Sent-Events and DataStax Ruby driver for Apache Cassandra}
  s.license       = 'MIT'
  s.files         = Dir['app/**/*.*', 'app.rb', 'README.md', 'bin/*']
  s.bindir        = 'bin'
  s.executables << 'cassandra-web'

  s.required_ruby_version = '>= 1.9.3'

  s.add_runtime_dependency 'cassandra-driver', '~> 3.1'
  s.add_runtime_dependency 'thin',             '~> 1.6'
  s.add_runtime_dependency 'rack-cors',        '>= 0.2', '< 2.0'
  s.add_runtime_dependency 'rack-parser',      '~> 0.6'
  s.add_runtime_dependency 'sinatra',          '~> 1.4'
  s.add_runtime_dependency 'lz4-ruby',         '~> 0.3'

  s.add_development_dependency 'bundler', '~> 1.6'
  s.add_development_dependency 'rake', '~> 12.3'
end
