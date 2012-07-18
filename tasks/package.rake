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
  major, minor, micro, *extra = version.split('.')
  puts "Ruby version #{major||0}.#{minor||0}.#{micro||0} #{extra.join('_')}"
  File::open('lib/rhc/version.rb', 'w') do |f|
    f << <<-VERSION_RB
module RHC
  module VERSION #:nocov:
    MAJOR = #{major||0}
    MINOR = #{minor||0}
    MICRO = #{micro||0}
    #PRE  = '#{extra.join('_')}'
    STRING = [MAJOR,MINOR,MICRO].compact.join('.')
  end
end
    VERSION_RB
  end
end

# Add the 'pkg' directory to the clean task
CLEAN.include("pkg")
