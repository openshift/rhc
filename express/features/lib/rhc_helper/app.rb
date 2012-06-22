require 'tmpdir'
require 'rhc-rest'

module RHCHelper
  #
  # Constant Definitions
  #
  TEMP_DIR = File.join(Dir.tmpdir, "rhc")

  #
  # A class to help maintain the state from rhc calls and helper
  # methods around application management.
  #
  class App 
    extend Persistable
    extend Runnable
    include Loggable
    include Commandify
    include Runnable
    include Persistify
    include Httpify

    # attributes to represent the general information of the application
    attr_accessor :name, :type, :hostname, :repo, :embed, :snapshot, :uid, :alias

    # mysql connection information
    attr_accessor :mysql_hostname, :mysql_user, :mysql_password, :mysql_database

    # Create the data structure for a test application
    def initialize(type, name)
      @name, @type = name, type
      @hostname = "#{name}-#{$namespace}.#{$domain}"
      @repo = "#{TEMP_DIR}/#{$namespace}_#{name}_repo"
      @file = "#{TEMP_DIR}/#{$namespace}.json"
      @embed = []
    end

    def self.rhc_setup
      if $namespace
        # Namespace is already created, so don't pass anything in
        run("rhc setup", nil, [$username, $password, 'yes', ''])
      else
        # Pass in a blank value for namespace to create in the next step
        run("rhc setup", nil, [$username, $password, 'yes', '', ''])
      end
    end

    def self.create_unique(type, prefix="test")
      # Get a REST client to verify the application name
      client = Rhc::Rest::Client.new($end_point, $username, $password)

      # Cleanup all test applications
      test_names = []
      client.domains.each do |domain|
        domain.applications.each do |app|
          test_names << app.name if app.name.start_with?(prefix)
        end
      end
      
      loop do
        # Generate a random application name
        chars = ("1".."9").to_a
        name = prefix + Array.new(8, '').collect{chars[rand(chars.size)]}.join

        # If the test name exists, try again
        next if test_names.index(name)

        # Create the app
        app = App.new(type, name)
        app.persist
        return app
      end
    end

    def get_index_file
      case @type
        when "php-5.3" then "php/index.php"
        when "ruby-1.8" then "config.ru"
        when "python-2.6" then "wsgi/application"
        when "perl-5.10" then "perl/index.pl"
        when "jbossas-7" then "src/main/webapp/index.html"
        when "jbosseap-6.0" then "src/main/webapp/index.html"
        when "nodejs-0.6" then "index.html"
      end
    end

    def get_mysql_file
      case @type
        when "php-5.3" then File.expand_path("../misc/php/db_test.php", File.expand_path(File.dirname(__FILE__)))
      end
    end
  end
end
