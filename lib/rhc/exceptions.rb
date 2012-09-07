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

  class KeyNotFoundException < Exception
    def initialize(message="SSHKey not found")
      super message, 118
    end
  end

  class DeprecatedError < RuntimeError; end
  
  class KeyFileNotExistentException < Exception
    def initialize(message="SSH Key file not found")
      super message, 128
    end
  end
  
  class KeyFileAccessDeniedException < Exception
    def initialize(message = "Insufficient acces to SSH Key file")
      super message, 128
    end
  end
end
