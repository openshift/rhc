$: << File.expand_path(File.join(File.dirname(__FILE__), "../lib"))

require 'rhc_helper'
require 'rhc-rest'
require 'rhc/config'

$username = ENV['RHC_USERNAME']
$password = ENV['RHC_PASSWORD']
$namespace = ENV['RHC_NAMESPACE']
$domain = ENV['RHC_DOMAIN'] || "rhcloud.com"
$end_point = ENV['RHC_ENDPOINT'] || "https://openshift.redhat.com/broker/rest/api"
raise "Username not found in environment (RHC_USERNAME)" unless $username
raise "Password not found in environment (RHC_PASSWORD)" unless $password

puts "\n\n"
puts "--------------------------------------------------------------------------------------------------"
puts "                Test Information"
puts "--------------------------------------------------------------------------------------------------"
puts "  Using REST End Point: #{$end_point}"
puts "  Using Domain: #{$domain}"
puts "  Creating New Namespace: #{$namespace.nil?}"
puts "--------------------------------------------------------------------------------------------------"
puts "\n\n"

puts "--------------------------------------------------------------------------------------------------"
puts "               Resetting environment"
puts "--------------------------------------------------------------------------------------------------"
# Start with a clean config
puts "  Replacing express.conf with the specified libra_server"
File.open(RHC::Config::local_config_path, 'w') {|f| f.write("libra_server=#{URI.parse($end_point).hostname}") }

puts "  Cleaning up test applications..."
FileUtils.rm_rf RHCHelper::TEMP_DIR

# Cleanup all test applications
client = Rhc::Rest::Client.new($end_point, $username, $password)
client.domains.each do |domain|
  domain.applications.each do |app|
    if app.name.start_with?("test")
      puts "    Deleting application #{app.name}"
      app.delete
    end
  end
end

puts "  Application cleanup complete"
puts "--------------------------------------------------------------------------------------------------"
puts "\n\n"

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
