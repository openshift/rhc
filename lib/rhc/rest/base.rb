module RHC
  module Rest
    class Base
      include Attributes
      extend AttributesClass

      define_attr :messages

      def initialize(attrs=nil, client=nil)
        @attributes = (attrs || {}).stringify_keys!
        @attributes['messages'] ||= []
        @client = client
      end

      def add_message(msg)
        messages << msg
      end

      def rest_method(link_name, payload={}, options={})
        link = link(link_name)
        raise "No link defined for #{link_name}" unless link
        url = link['href']
        url = url.gsub(/:\w+/) { |s| options[:params][s] } if options[:params]
        method = options[:method] || link['method']

        client.request(options.merge({
          :url => url,
          :method => method,
          :payload => payload,
        }))
      end

      def links
        attributes['links'] || {}
      end

      def supports?(sym)
        !!link(sym)
      end

      def has_param?(sym, name)
        if l = link(sym)
          (l['required_params'] || []).any?{ |p| p['name'] == name} or (l['optional_params'] || []).any?{ |p| p['name'] == name}
        end
      end

      protected
        attr_reader :client

        def link(sym)
          (links[sym.to_s] || links[sym.to_s.upcase])
        end

        def debug(msg, obj=nil)
          client.debug("#{msg}#{obj ? " #{obj}" : ''}") if client && client.debug?
        end

        def debug?
          client && client.debug?
        end
    end
  end
end
