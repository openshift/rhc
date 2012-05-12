require 'rhc/cli'

class RHC::Commands::Base

  protected

    def self.inherited(klass)
      unless klass == RHC::Commands::Base
      end
    end

    def self.method_added(method)
      return if self == RHC::Commands::Base
      return if private_method_defined? method
      return if protected_method_defined? method

      method_name = method.to_s == 'run' ? nil : method.to_s
      name = [self.object_name, method].compact.join(' ')
      command name do |c|
        c.when_called self, method
      end
    end

    def self.object_name
      nil
    end
end
