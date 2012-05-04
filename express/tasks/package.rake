#!/usr/bin/ruby

require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/testtask'

begin
  require 'rubygems/package_task'
rescue LoadError
  require 'rake/gempackagetask'
  rake_gempackage = true
end

task(:default).clear
task :default => [:package]

# Create the gem specification for packaging
spec = Gem::Specification.new do |s|
    s.name = %q{rhc}
    s.version = /(Version: )(.*)/.match(File.read("client.spec"))[2]
    s.author = "Red Hat"
    s.email = %q{openshift@redhat.com}
    s.summary = %q{OpenShift Client Tools}
    s.homepage = %q{https://openshift.redhat.com/app/express}
    s.description = %q{The client tools for the OpenShift platform that allow for application management.}
    s.files = FileList['lib/**/*.rb', 'lib/rhc', 'bin/*', 'conf/*'].to_a
    s.files += %w(LICENSE COPYRIGHT README.md Rakefile)
    s.executables = ['rhc', 'rhc-domain', 'rhc-app', 'rhc-sshkey', 'rhc-chk', 'rhc-create-app', 'rhc-create-domain', 'rhc-ctl-domain', 'rhc-ctl-app', 'rhc-snapshot', 'rhc-domain-info', 'rhc-user-info', 'rhc-tail-files', 'rhc-port-forward']
    s.add_dependency('parseconfig')
    s.add_dependency("rest-client")
    # This does not need to be added as a dep for the RPM since it is only needed in extension installation
    s.add_dependency('rake')

    # Adding install time dependencies for
    #   - test-unit (Ruby 1.9)
    #   - json_pure (Ruby (Ruby 1.8.6, Windows, Mac) / json (everything else)
    # http://en.wikibooks.org/wiki/Ruby_Programming/RubyGems
    s.extensions << 'ext/mkrf_conf.rb'
end

# Define a :package task that bundles the gem
if rake_gempackage
  Rake::GemPackageTask.new(spec) do |pkg, args|
    pkg.need_tar = false
  end
else
  Gem::PackageTask.new(spec) do |pkg, args|
    pkg.need_tar = false
  end
end

# Add the 'pkg' directory to the clean task
CLEAN.include("pkg")
