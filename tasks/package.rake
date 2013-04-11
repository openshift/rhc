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

task :version, :version do |t, args|
  version = args[:version] || /(Version: )(.*)/.match(File.read("client.spec"))[2]
  raise "No version specified" unless version
  puts "RPM version  #{version}"
end

# Add the 'pkg' directory to the clean task
CLEAN.include("pkg")

task :autocomplete do
  require 'rhc'
  RHC::Commands.load.to_commander
  IO.write('autocomplete/rhc_bash', RHC::AutoComplete.new.to_s)
end