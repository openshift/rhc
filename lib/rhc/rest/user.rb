require 'rhc/rest/base'

module RHC
  module Rest
    class User < Base
      attr_reader :login

      def add_key(name, content, type)
        debug "Add key #{name} of type #{type} for user #{login}"
        rest_method "ADD_KEY", :name => name, :type => type, :content => content
      end

      def keys
        debug "Getting all keys for user #{login}"
        rest_method "LIST_KEYS"
      end

      #Find Key by name
      def find_key(name)
        filtered = Array.new
        #TODO do a regex caomparison
        keys.each { |key| filtered.push(key) if key.name == name }
        filtered
      end
    end
  end
end
