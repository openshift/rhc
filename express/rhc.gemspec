# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
#require "rhc/version" #FIXME Need specific version

Gem::Specification.new do |s|
  s.name         = %q{rhc}
  s.version      = /(Version: )(.*)/.match(File.read("client.spec"))[2]
  #s.version     = Rhc::VERSION

  s.authors      = %q{Red Hat}
  s.email        = %q{dev@openshift.redhat.com}
  s.summary      = %q{OpenShift Client Tools}
  s.homepage     = %q{https://github.com/openshift/os-client-tools}
  s.description  = %q{The client tools for the OpenShift platform that allow for application management.}

  s.files        = Dir['lib/**/*.rb', 'lib/rhc bin/*', 'conf/*'] + %w(LICENSE COPYRIGHT README.md Rakefile)
  s.test_files   = Dir['{test,spec,features}/**/*']
  s.executables  = Dir['bin/*'].map{ |f| File.basename(f) }
  s.require_path = 'lib'

  s.add_dependency              'net-ssh'
  s.add_dependency              'archive-tar-minitar'
  s.add_dependency              'test-unit' # used by rhc domain status in ruby 1.9
  s.add_runtime_dependency      'commander',    '>= 4.0'
  s.add_runtime_dependency      'rest-client',  '>= 1.6'
  s.add_development_dependency  'rake'
  s.add_development_dependency  'webmock',      '>= 1.6'
  s.add_development_dependency  'rspec',        '~> 1.3'
  s.add_development_dependency  'fakefs',       '>= 0.4'
end
