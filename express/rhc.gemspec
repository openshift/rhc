# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
#require "rhc/version" #FIXME Need specific version

Gem::Specification.new do |s|
  s.name         = %q{rhc}
  s.version      = /(Version: )(.*)/.match(File.read("client.spec"))[2]
  #s.version     = Rhc::VERSION

  s.authors      = %q{Red Hat}
  s.email        = %q{openshift@redhat.com}
  s.summary      = %q{OpenShift Client Tools}
  s.homepage     = %q{https://github.com/openshift/os-client-tools}
  s.description  = %q{The client tools for the OpenShift platform that allow for application management.}

  s.files        = Dir['lib/**/*.rb', 'lib/rhc bin/*', 'conf/*'] + %w(LICENSE COPYRIGHT README.md Rakefile)
  s.test_files   = Dir['{test,spec,features}/**/*']
  s.executables  = Dir['bin/*'].map{ |f| File.basename(f) }
  s.require_path = 'lib'

  s.add_dependency              'rake'                    # required only for extension support
  s.add_dependency              'sshkey'
  s.add_dependency              'net-ssh'
  s.add_dependency              'archive-tar-minitar'
  s.add_runtime_dependency      'parseconfig'
  s.add_runtime_dependency      'rest-client',  '>= 1.6'
  s.add_development_dependency  'test-unit',    '>= 2.2'

  # Adding install time dependencies for
  #   - test-unit (Ruby 1.9)
  #   - json_pure (Ruby (Ruby 1.8.6, Windows, Mac) / json (everything else)
  # http://en.wikibooks.org/wiki/Ruby_Programming/RubyGems
  s.extensions << 'ext/mkrf_conf.rb'
