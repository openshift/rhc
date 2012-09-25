require 'base64'
require 'rhc/json'

module RHC
  module Rest
    class Base
      include Rest

      attr_reader :messages

      def initialize(json_args={})
        @__json_args__ = json_args
        @messages = []
      end

      def add_message(msg)
        @messages << msg
      end

      private
        def debug(msg)
          logger.debug(msg) if @debug
        end

        def rest_method(link_name, payload={}, timeout=nil)
          url = links[link_name]['href']
          method =  links[link_name]['method']

          request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload, :timeout => timeout)
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
