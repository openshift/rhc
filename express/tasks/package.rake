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

spec = Gem::Specification.load('rhc.gemspec')

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
