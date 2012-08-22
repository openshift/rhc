require 'rhc/vendor/okjson'

module RHC

  module Json

    def self.decode(string, options={})
      string = string.read if string.respond_to?(:read)
      result = RHC::Vendor::OkJson.decode(string)
      options[:symbolize_keys] ? symbolize_keys(result) : result
    end

    def self.encode(object, options={})
      RHC::Vendor::OkJson.valenc(stringify_keys(object))
    end

    def self.symbolize_keys(object)
      modify_keys(object) do |key|
        key.is_a?(String) ? key.to_sym : key
      end
    end

    def self.stringify_keys(object)
      modify_keys(object) do |key|
        key.is_a?(Symbol) ? key.to_s : key
      end
    end

    def self.modify_keys(object, &modifier)
      case object
      when Array
        object.map do |value|
          modify_keys(value, &modifier)
        end
      when Hash
        object.inject({}) do |result, (key, value)|
          new_key   = modifier.call(key)
          new_value = modify_keys(value, &modifier)
          result.merge! new_key => new_value
        end
      else
        object
      end
    end

  end

  class JsonError < ::StandardError; end

end

