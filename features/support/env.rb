$: << File.expand_path(File.join(File.dirname(__FILE__), "../lib"))
require 'rhc/coverage_helper'

require 'rhc_helper'
require 'rhc-rest'
require 'rhc/config'

# Generate a random username in case one isn't set
chars = ("1".."9").to_a
random_username = "test" + Array.new(8, '').collect{chars[rand(chars.size)]}.join + "@example.com"

 ENV["PATH"] = "#{ENV['RHC_LOCAL_PATH']}:#{ENV['PATH']}" if ENV['RHC_LOCAL_PATH']

# Generate a random username if one isn't specified (for unauthenticated systems)
$username = ENV['RHC_USERNAME'] || random_username

# Use a generic password if one isn't specific (for unauthenticated systems)
$password = ENV['RHC_PASSWORD'] || 'test'

# Default the domain to production unless a random username is used.
# In that case, use dev.rhcloud.com for the development DNS namespace
default_domain = ENV['RHC_USERNAME'] ? "rhcloud.com" : "dev.rhcloud.com"
$domain = ENV['RHC_DOMAIN'] || default_domain

# Default the endpoint to the production REST API's
$end_point = ENV['RHC_ENDPOINT'] || "https://openshift.redhat.com/broker/rest/api"

# Don't default the namespace to anything - the existance if checked to
# determine how the setup wizard is run
$namespace = ENV['RHC_NAMESPACE']

raise "Username not found in environment (RHC_USERNAME)" unless $username
raise "Password not found in environment (RHC_PASSWORD)" unless $password

puts "\n\n"
puts "--------------------------------------------------------------------------------------------------"
puts "                Test Information"
puts "--------------------------------------------------------------------------------------------------"
puts "  REST End Point: #{$end_point}"
puts "  Domain: #{$domain}"
puts "  Username: #{$username}"
puts "  Creating New Namespace: #{$namespace.nil?}"
puts "--------------------------------------------------------------------------------------------------"
puts "\n\n"

unless ENV['NO_CLEAN']
  puts "--------------------------------------------------------------------------------------------------"
  puts "               Resetting environment"
  puts "--------------------------------------------------------------------------------------------------"
  # Start with a clean config
  puts "  Replacing express.conf with the specified libra_server"
  File.open(RHC::Config::local_config_path, 'w') {|f| f.write("libra_server=#{URI.parse($end_point).host}") }

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
end

AfterConfiguration do |config|
  # Create the temporary space
  FileUtils.mkdir_p RHCHelper::TEMP_DIR

  # Persist the username used for the tests - in case it was auto-generated
  File.open(File.join(RHCHelper::TEMP_DIR, 'username'), 'w') {|f| f.write($username)}

  # Setup the logger
  logger = Logger.new(File.join(RHCHelper::TEMP_DIR, "cucumber.log"))
  logger.level = Logger::DEBUG
  RHCHelper::Loggable.logger = logger

  # Setup performance monitor logger
  perf_logger = Logger.new(File.join(RHCHelper::TEMP_DIR, "perfmon.log"))
  perf_logger.level = Logger::INFO
  RHCHelper::Loggable.perf_logger = perf_logger
end

After do |s| 
  # Tell Cucumber to quit after this scenario is done - if it failed.
  Cucumber.wants_to_quit = true if s.failed?
end

World(RHCHelper)
