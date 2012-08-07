require 'rhc-rest/exceptions/exceptions'
module RHC
  class DomainNotFoundException < Rhc::Rest::ResourceNotFoundException
    def initialize(message="Domain not found")
      super message, 127
    end
  end
end
