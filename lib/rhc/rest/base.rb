require 'base64'
require 'rhc/json'
require 'rhc/rest/attributes'

module RHC
  module Rest
    class Base
      include Rest
      include Attributes
      extend AttributesClass

      define_attr :messages

      def initialize(json_args=nil, use_debug=false)
        @debug = use_debug
        @attributes = (json_args || {}).stringify_keys!
        @messages = []
      end

      def add_message(msg)
        @messages << msg
      end

      protected
        def debug?
          @debug
        end

      private
        def debug(msg, obj=nil)
          logger.debug("#{msg}#{obj ? " #{obj}" : ''}") if debug?
        end

        def rest_method(link_name, payload={}, timeout=nil)
          link = links[link_name.to_s]
          raise "No link defined for #{link_name}" unless link
          url = link['href']
          method = link['method']

          request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload, :timeout => timeout)
          request(request)
        end

        def links
          attributes['links'] || {}
        end
    end
  end
end
