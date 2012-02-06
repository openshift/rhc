require "rhc-rest/version"
require 'rest-client'

module Rhc
  module Rest
    class Client
      def initialize(end_point, username, password)
        @end_point = endpoint
        @username = username
        @password = password
        request = RestClient::Request.new(:url => @end_point, :method => :get, :username => @username, :password => password)
        begin
          response = request.execute
        rescue RestClient::ExceptionWithResponse => e
        end
      end
      def domains
        
      end
      def cartridges
      end
      def keys
      end
      def logout
      end
    end
    class Domain
      attr_accessor :namespace
      def initialize(namespace)
        @namespace = namespace
      end
      def applications
      end
      def update
      end
      def destory
      end
    end
    class Application
      attr_accessor :domain, :name, :creation_time, :uuid, :aliases, :server_identity
      def initialize(domain, name)
      end
      def cartridges
      end
      def start
      end
      def stop(force=false)
      end
      def restart
      end
      def destroy
      end
    end
    class Cartridges
    end
    class Key
      attr_accessor :name, :type, :ssh
      def initialize(name, type, ssh)
        @name = name
        @type = type
        @ssh = ssh
      end
    end
  end
end
