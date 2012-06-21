$: << File.expand_path(File.join(File.dirname(__FILE__), "../lib"))

require 'rhc_helper'
require 'rhc-rest'

puts "Cleaning up environment before beginning"
FileUtils.rm_rf RHCHelper::TEMP_DIR

$username = ENV['RHC_USERNAME']
$password = ENV['RHC_PASSWORD']
$namespace = ENV['RHC_NAMESPACE']
$end_point = ENV['RHC_ENDPOINT'] || "https://openshift.redhat.com/broker/rest/api"
raise "Username not found in environment (RHC_USERNAME)" unless $username
raise "Password not found in environment (RHC_PASSWORD)" unless $password
raise "Namespace not found in environment (RHC_NAMESPACE)" unless $namespace

# Cleanup all test applications
client = Rhc::Rest::Client.new($end_point, $username, $password)
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
