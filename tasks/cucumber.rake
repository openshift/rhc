require 'cucumber'
require 'cucumber/rake/task'
require 'fileutils'

task :check_features do
  fail "Must specify RHC_SERVER or RHC_ENDPOINT" unless ENV['RHC_ENDPOINT'] or ENV['RHC_SERVER']
  if ENV['RHC_SERVER']
    endpoint = "https://#{ENV['RHC_SERVER']}/broker/rest/api"
    puts "Using '#{endpoint}' to test rest api"
    ENV['RHC_ENDPOINT'] = endpoint
  end
end

task :check_features_local do
  ENV['RHC_FEATURE_COVERAGE'] = '1'
  ENV['RHC_LOCAL_PATH'] = "#{File.join(Dir.pwd, 'bin')}"

  # clean coverage results so we do not not merged with stale data
  coverage_file = './coverage/features/.resultset.json'
  FileUtils.rm(coverage_file) if File.exists?(coverage_file)

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

desc "Run integration suite on local bundle"
Cucumber::Rake::Task.new(:features_local => :check_features_local) do |t|
  t.cucumber_opts = "features"
end

task :cucumber => [:features]
task :cucumber_local => [:features_local]
