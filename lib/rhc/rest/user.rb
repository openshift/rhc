require 'ostruct'

module RHC
  module Rest
    class User < Base
      define_attr :id, :login, :plan_id, :max_gears, :consumed_gears, :max_domains

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
        keys.detect { |key| key.name == name }
      end

      def max_domains
        attributes[:max_domains] || 1
      end

      def capabilities
        @capabilities ||= OpenStruct.new attribute('capabilities')
      end
    end
  end
end
