$: << File.expand_path(File.join(File.dirname(__FILE__), "../lib"))

require 'rhc/coverage_helper'
SimpleCov.at_exit{ SimpleCov.result.format! } if defined? SimpleCov

require 'rhc_helper'
require 'rhc/rest'
require 'rhc/config'
require 'rhc/helpers'
require 'rhc/commands'

def set_path
  ENV["PATH"] = "#{ENV['RHC_LOCAL_PATH']}:#{ENV['PATH']}" if ENV['RHC_LOCAL_PATH']
end

def set_creds
  # Get the value from the file
  def from_file(filename)
    value =  File.exists?(filename) ? File.read(filename) : ""
    value.empty? ? nil : value
  end

  # If NO_CLEAN is specified, reuse the variables if specified
  if ENV['NO_CLEAN']
    ENV['RHC_USERNAME'] ||= from_file('/tmp/rhc/username')
    ENV['RHC_NAMESPACE'] ||= from_file('/tmp/rhc/namespace')
  end

  # Generate a random username in case one isn't set
  chars = ("1".."9").to_a
  random_username = "test" + Array.new(8, '').collect{chars[rand(chars.size)]}.join + "@example.com"

  # Generate a random username if one isn't specified (for unauthenticated systems)
  $username = ENV['RHC_USERNAME'] || random_username

  # Use a generic password if one isn't specific (for unauthenticated systems)
  $password = ENV['RHC_PASSWORD'] || 'test'

  # Default the domain to production unless a random username is used.
  # In that case, use dev.rhcloud.com for the development DNS namespace
  default_domain = ENV['RHC_USERNAME'] ? "rhcloud.com" : "dev.rhcloud.com"
  $domain = ENV['RHC_DOMAIN'] || default_domain

  # Don't default the namespace to anything - the existance if checked to
  # determine how the setup wizard is run
  $namespace = ENV['RHC_NAMESPACE']
end

def set_endpoint
  # Use either the ENV variable, our libra_server, or prod
  ENV['RHC_SERVER'] ||= (ENV['RHC_DEV'] ? RHC::Config['libra_server'] : 'openshift.redhat.com')
  # Format the endpoint properly
  ENV['RHC_ENDPOINT'] ||= "https://%s/broker/rest/api" % ENV['RHC_SERVER']
  $end_point =  ENV['RHC_ENDPOINT']
end

### Run initialization commands
# Set the PATH env variable
set_path
# Set the username,password,etc based on env variables or defaults
set_creds
# Set the endpoint to test against
set_endpoint

raise "Username not found in environment (RHC_USERNAME)" unless $username
raise "Password not found in environment (RHC_PASSWORD)" unless $password

$user_register_script_format = "/usr/bin/ss-register-user -l admin -p admin --username %s --userpass %s"
if ENV['REGISTER_USER']
  command = $user_register_script_format % [$username,$password]
  %x[#{command}]
end

def _log(msg)
  puts msg unless ENV['QUIET']
end

_log "\n\n"
_log "--------------------------------------------------------------------------------------------------"
_log "                Test Information"
_log "--------------------------------------------------------------------------------------------------"
_log "  REST End Point: #{$end_point}"
_log "  Domain: #{$domain}"
_log "  Username: #{$username}"
_log "  Creating New Namespace: #{$namespace.nil?}"
_log "--------------------------------------------------------------------------------------------------"
_log "\n\n"

def clean_applications(leave_domain = false)
  return if ENV['NO_CLEAN']
  users = [$username,'user_with_multiple_gear_sizes@test.com']

  _log "  Cleaning up test applications..."

  users.each do |user|
    _log "\tUser: #{user}"
    client = RHC::Rest::Client.new($end_point, user, $password)
    client.domains.each do |domain|
      _log "\t\tDomain: #{domain.id}"
      domain.applications.each do |app|
        if app.name.start_with?("test")
          _log "\t\t\tApplication: #{app.name}"
          app.delete
        end
      end
      domain.delete unless leave_domain
    end
    client.sshkeys.each do |key|
      _log "\t\tKey: #{key.name}"
      key.delete
    end
  end
end

unless ENV['NO_CLEAN']
  _log "--------------------------------------------------------------------------------------------------"
  _log "               Resetting environment"
  _log "--------------------------------------------------------------------------------------------------"
  # Ensure the directory for local_config_path exists
  config_dir = File.dirname(RHC::Config::local_config_path)
  Dir::mkdir(config_dir) unless File.exists?(config_dir)

  # Start with a clean config
  _log "  Replacing express.conf with the specified libra_server"
  File.open(RHC::Config::local_config_path, 'w') {|f| f.write("libra_server=#{URI.parse($end_point).host}") }
  RHC::Config.initialize

  # Clean up temp dir
  FileUtils.rm_rf RHCHelper::TEMP_DIR

  # Clean up applications
  clean_applications

  _log "--------------------------------------------------------------------------------------------------"
  _log "\n\n"
end

AfterConfiguration do |config|
  # Create the temporary space
  FileUtils.mkdir_p RHCHelper::TEMP_DIR

  # Persist the username used for the tests - in case it was auto-generated
  File.open(File.join(RHCHelper::TEMP_DIR, 'username'), 'w') {|f| f.write($username)}

  # Modify the .ssh/config so the git and ssh commands can succeed
  keyfile = RHCHelper::Sshkey.keyfile_path('key1')
  begin
    File.open('/root/.ssh/config','w',0600) do |f|
      f.puts "Host *"
      f.puts "\tStrictHostKeyChecking no"
      f.puts "\tIdentityFile #{keyfile}"
      f.puts "\tIdentityFile /root/.ssh/id_rsa"
    end
  rescue Errno::ENOENT, Errno::EACCES
  end
  #File.chmod(0600,keyfile)

  # Setup the logger
  logger = Logger.new(File.join(RHCHelper::TEMP_DIR, "rhc_cucumber.log"))
  logger.level = Logger::DEBUG
  RHCHelper::Loggable.logger = logger
  $logger = logger

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
