require 'rhc/commands/base'

module RHC::Commands
  class Status < Base
    def run
      say 'Check server status'
    end
  end
end
