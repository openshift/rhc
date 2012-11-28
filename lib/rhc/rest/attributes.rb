module RHC::Rest::Attributes
  def attributes
    @attributes
  end

  def attributes=(attr=nil)
    @attributes = (attr || {}).stringify_keys!
  end

  def attribute(name)
    instance_variable_get("@#{name}") || attributes[name.to_s]
  end
end

module RHC::Rest::AttributesClass
  def define_attr(*names)
    names.map(&:to_sym).each do |name|
      define_method(name) do
        attribute(name)
      end
      define_method("#{name}=") do |value|
        instance_variable_set(:"@#{name}", nil)
        attributes[name.to_s] = value
      end
    end
  end
end
