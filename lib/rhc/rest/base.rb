require 'base64'
require 'rhc/json'

module RHC
  module Rest
    class Base
      include Rest

      attr_reader :messages
      attr_accessor :headers, :api_version

      def initialize(json_args={}, use_debug=false, api_version=nil)
        @debug = use_debug
        @__json_args__ = json_args
        @messages = []
        @headers = {:accept => :json}
        set_auth_header
        @headers["User-Agent"] = RHC::Helpers.user_agent
        if api_version
          @api_version = api_version
          headers["Accept"] = "application/json;version=#{api_version}"
        end
      end

      def add_message(msg)
        @messages << msg
      end
      
      # set up 'Authorization' header based on @user and @pass
      def set_auth_header(username = nil, password = nil)
        username ||= @user
        password ||= @pass
        if Base64.class.respond_to? :strict_encode64
          credentials = Base64.strict_encode64("#{username}:#{password}")
        else
          credentials = Base64.encode64("#{username}:#{password}").delete("\n")
        end
        @headers["Authorization"] = "Basic #{credentials}"
      end

      private
        def debug(msg)
          logger.debug(msg) if @debug
        end

        def rest_method(link_name, payload={}, timeout=nil)
          url = links[link_name]['href']
          method =  links[link_name]['method']

          request = new_request(:url => url, :method => method, :headers => @headers, :payload => payload, :timeout => timeout)
          debug "Request: #{request.inspect}"
          request(request)
        end

        def links
          @__json_args__[:links] || @__json_args__['links']
        end

        def self.attr_reader(*names)
          names.each do |name|
            define_method(name) do
              instance_variable_get("@#{name}") || @__json_args__[name] || @__json_args__[name.to_s]
            end
          end
        end
    end
  end
end
