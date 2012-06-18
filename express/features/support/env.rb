$: << File.expand_path(File.join(File.dirname(__FILE__), "../lib"))

require 'rhc_helper'
require 'rhc-rest'

puts "Cleaning up environment before beginning"
FileUtils.rm_rf RHCHelper::TEMP_DIR

end_point = "https://openshift.redhat.com/broker/rest/api"
username = ENV['RHC_RHLOGIN']
password = ENV['RHC_PWD']
namespace = ENV['RHC_NAMESPACE']
unless username && password && namespace
  puts "ERROR - Environment not setup"
  exit 1
end

# Cleanup all test applications
client = Rhc::Rest::Client.new(end_point, username, password)
client.domains.each do |domain|
  domain.applications.each do |app|
    if app.name.start_with?("test")
      puts "Cleaning up application #{app.name}"
      app.delete
    end
  end
end

AfterConfiguration do |config|
  # Create the temporary space
  FileUtils.mkdir_p RHCHelper::TEMP_DIR

  # Setup the logger
  logger = Logger.new(File.join(RHCHelper::TEMP_DIR, "cucumber.log"))
  logger.level = Logger::DEBUG
  RHCHelper::Loggable.logger = logger

  # Setup performance monitor logger
  perf_logger = Logger.new(File.join(RHCHelper::TEMP_DIR, "perfmon.log"))
  perf_logger.level = Logger::INFO
  RHCHelper::Loggable.perf_logger = perf_logger
end

World(RHCHelper)
