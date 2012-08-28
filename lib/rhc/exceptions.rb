module RHC
  class Exception < StandardError
    attr_reader :code
    def initialize(message=nil, code=nil)
      super(message)
      @code = code
    end
  end

  class DomainNotFoundException < Exception
    def initialize(message="Domain not found")
      super message, 127
    end
  end

  class ApplicationNotFoundException < Exception
    def initialize(message="Application not found")
      super message, 101
    end
  end

  class CartridgeNotFoundException < Exception
    def initialize(message="Cartridge not found")
      super message, 154
    end
  end

  class KeyNotFoundException < Exception
    def initialize(message="SSHKey not found")
      super message, 118
    end
  end

  class DeprecatedError < RuntimeError; end
end
