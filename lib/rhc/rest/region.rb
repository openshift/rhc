module RHC::Rest
  class Region < Base
    define_attr :id, :name, :description, :default, :allow_selection

    def default?
      !!default
    end

    def allow_selection?
      !!allow_selection
    end

    def uuid
      client.api_version_negotiated >= 1.6 ? attributes['id'] : attributes['uuid']
    end

    def zones
      @zones ||= attributes['zones'].map{|z| z['name']}.sort
    end

    def <=>(other)
      return self.name <=> other.name
    end

    def to_s
      self.name
    end
  end
end
