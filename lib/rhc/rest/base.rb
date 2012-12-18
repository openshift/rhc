require 'rhc/rest/attributes'

module RHC
  module Rest
    class Base
      include Attributes
      extend AttributesClass

      define_attr :messages

      def initialize(attrs=nil, client=nil)
        @attributes = (attrs || {}).stringify_keys!
        @client = client
        @messages = []
      end

      def add_message(msg)
        @messages << msg
      end

      def rest_method(link_name, payload={}, timeout=nil)
        link = links[link_name.to_s]
        raise "No link defined for #{link_name}" unless link
        url = link['href']
        method = link['method']

        client.request(
          :url => url,
          :method => method,
          :payload => payload
        )
      end

      def links
        attributes['links'] || {}
      end

      protected
        attr_reader :client

        def debug(msg, obj=nil)
          client.debug("#{msg}#{obj ? " #{obj}" : ''}") if client.debug?
        end

    end
  end
end
