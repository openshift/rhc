# From Rails core_ext/object.rb
require 'rhc/json'

class Object
  def present?
    !blank?
  end
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  # Avoid a conflict if to_json is already defined
  unless Object.public_methods.include? :to_json
    def to_json
      RHC::Json.encode(self)
    end
  end
end
