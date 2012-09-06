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

  class ScaledApplicationsNotSupportedException < Exception
    def initialize(message="Scaled applications not supported")
      super message, 128
    end
  end

  class PermissionDeniedException < Exception
    def initialize(message="Permission denied")
      super message, 129
    end
  end

  class NoPortsToForwardException < Exception
    def initialize(message="No available ports to forward")
      super message, 102
    end
  end

  class PortForwardFailedException < Exception
    def initialize(message="Port forward failed")
      super message, 1
    end
  end
end
