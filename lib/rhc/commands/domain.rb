require 'rhc/commands/base'

module RHC::Commands
  class Domain < Base

    summary "Manage your namespace"
    def create(*args)
      puts "you called create!"
    end
  end

end
