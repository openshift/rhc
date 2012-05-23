# From Rails core_ext/object.rb
class Object
  def present?
    !blank?
  end
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def to_json
    Rhc::Vendor::OkJson.encode(self)
  end
end
