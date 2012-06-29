require 'cucumber'
require 'cucumber/rake/task'

task :check_features do
  fail "Must specify RHC_SERVER or RHC_ENDPOINT" unless ENV['RHC_ENDPOINT'] or ENV['RHC_SERVER']
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

task :cucumber => [:features]

