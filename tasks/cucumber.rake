require 'cucumber'
require 'cucumber/rake/task'
require 'fileutils'

task :check_cucumber do
end

task :check_cucumber_local do
  ENV['RHC_FEATURE_COVERAGE'] = '1'
  ENV['RHC_LOCAL_PATH'] = "#{File.join(Dir.pwd, 'bin')}"

  # clean coverage results so we do not not merged with stale data
  coverage_file = './coverage/cucumber/.resultset.json'
  FileUtils.rm(coverage_file) if File.exists?(coverage_file)
end

desc "Run integration suite"
Cucumber::Rake::Task.new(:cucumber => :check_cucumber) do |t|
  t.cucumber_opts = "cucumber"
end

desc "Run integration suite on local bundle"
Cucumber::Rake::Task.new(:cucumber_local => :check_cucumber_local) do |t|
  t.cucumber_opts = "cucumber"
end
