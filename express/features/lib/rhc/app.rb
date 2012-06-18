require 'dnsruby'
require 'tmpdir'
require 'rhc-rest'

module RHCHelper
  #
  # Constant Definitions
  #
  TEMP_DIR = File.join(Dir.tmpdir, "rhc")
  DOMAIN = "rhcloud.com"

  #
  # A class to help maintain the state from rhc calls
  #
  class App 
    extend Persistable
    include Dnsruby
    include Loggable
    include Commandify
    include Runnable
    include Persistify
    include Httpify

    # attributes to represent the general information of the application
    attr_accessor :name, :namespace, :login, :password, :type, :hostname, :repo, :embed, :snapshot, :uid, :alias

    # mysql connection information
    attr_accessor :mysql_hostname, :mysql_user, :mysql_password, :mysql_database

    # Create the data structure for a test application
    def initialize(namespace, login, type, name, password=nil)
      @name, @namespace, @login, @type, @password = name, namespace, login, type, password
      @hostname = "#{name}-#{namespace}.#{DOMAIN}"
      @repo = "#{TEMP_DIR}/#{namespace}_#{name}_repo"
      @file = "#{TEMP_DIR}/#{namespace}.json"
      @embed = []
    end

    def self.create_unique(type, prefix="test")
      end_point = "https://openshift.redhat.com/broker/rest/api"
      username = ENV['RHC_USERNAME']
      password = ENV['RHC_PASSWORD']
      namespace = ENV['RHC_NAMESPACE']
      raise "Username not found in environment (RHC_USERNAME)" unless username
      raise "Password not found in environment (RHC_PASSWORD)" unless password
      raise "Namespace not found in environment (RHC_NAMESPACE)" unless namespace

      # Get a REST client to verify the application name
      client = Rhc::Rest::Client.new(end_point, username, password)

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
        app = App.new(namespace, username, type, name, password)
        app.persist
        return app
      end
    end

    def reserved?
      # If we get a response, then the namespace is reserved
      # An exception means that it is available
      begin
        Dnsruby::Resolver.new.query("#{@namespace}.#{DOMAIN}", Dnsruby::Types::TXT)
        return true
      rescue Dnsruby::NXDomain
        return false
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
