require 'rubygems'
require 'rubygems/command.rb'
require 'rubygems/dependency_installer.rb' 
begin
  Gem::Command.build_args = ARGV
rescue NoMethodError
end 
inst = Gem::DependencyInstaller.new
begin
  if ENV['JSON_PURE'] or (RUBY_VERSION == "1.8.6" or RUBY_PLATFORM =~ /mswin/ or RUBY_PLATFORM =~ /darwin/)
    inst.install('json_pure')
  else
    inst.install('json')
  end
rescue
  exit(1)
end 

f = File.open(File.join(File.dirname(__FILE__), "Rakefile"), "w")   # create dummy rakefile to indicate success
f.write("task :default\n")
f.close
