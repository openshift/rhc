require 'rhc-rest/exceptions/exceptions'
module RHC
  class DomainNotFoundException < Rhc::Rest::ResourceNotFoundException
    def initialize(message="Domain not found")
      super message, 127
    end
  end

  class ApplicationNotFoundException < Rhc::Rest::ResourceNotFoundException
    def initialize(message="Application not found")
      super message, 101
    end
  end

  class KeyNotFoundException < Rhc::Rest::ResourceNotFoundException
    def initialize(message="SSHKey not found")
      super message, 118
    end
  end
end
