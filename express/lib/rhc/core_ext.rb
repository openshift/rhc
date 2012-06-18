# From Rails core_ext/object.rb
require 'rhc/json'
require 'parseconfig'

class Object
  def present?
    !blank?
  end
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def to_json
    RHC::Json.encode(self)
  end
end


unless ParseConfig.method_defined?('[]')
  class ParseConfig
    def [](key)
      get_value(key)
    end
  end
end
