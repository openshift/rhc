require "spec/rake/spectask"
require 'cucumber'
require 'cucumber/rake/task'

desc "Run specs"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.verbose = false
end

task :default => :spec
task :test => [:spec, :features]
