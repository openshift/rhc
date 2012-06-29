require "spec/rake/spectask"
require 'cucumber'
require 'cucumber/rake/task'

desc "Check environment for spec"
task :check_features do
  fail "Must specify RHC_SERVER or RHC_ENDPOINT in the environment" unless ENV['RHC_ENDPOINT'] or ENV['RHC_SERVER']
  if ENV['RHC_SERVER']
    endpoint = "https://#{ENV['RHC_SERVER']}/broker/rest/api"
    puts "Using '#{endpoint}' to test rest api"
    ENV['RHC_ENDPOINT'] = endpoint
  end
end

desc "Run integration suite"
Cucumber::Rake::Task.new(:features => :check_features) do |t|
  t.cucumber_opts = "features"
end

desc "Run specs"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.verbose = false
  t.spec_opts = ['--color']
end

task :default => :spec
task :test => [:spec, :features]

if false
original_stderr = $stderr
SimpleCov.at_exit do
  begin
    SimpleCov.result.format!
    if SimpleCov.result.covered_percent < 100.0
      original_stderr.puts "Coverage not 100%, build failed."
      exit 1
    end
  rescue
    puts "No coverage check, older Ruby"
  end
end
end
