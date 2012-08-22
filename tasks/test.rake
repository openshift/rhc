require 'rspec/core/rake_task'
require 'cucumber'
require 'cucumber/rake/task'

desc "Run specs"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.verbose = false
  t.rspec_opts = ['--color']
end

task :default => :spec
task :test => [:spec, :features]
