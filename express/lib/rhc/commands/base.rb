require 'rhc/cli'

class RHC::Commands::Base

  protected

    class InvalidCommand < StandardError ; end

    def self.inherited(klass)
      unless klass == RHC::Commands::Base
      end
    end

    def self.method_added(method)
      return if self == RHC::Commands::Base
      return if private_method_defined? method
      return if protected_method_defined? method

      method_name = method.to_s == 'run' ? nil : method.to_s
      name = [method_name]
      name.unshift(self.object_name).compact!
      raise InvalidCommand, "Either object_name must be set or a non default method defined" if name.empty?
      command name.join(' ') do |c|
        c.when_called self, method
      end
    end

    def self.object_name(value=nil)
      @object_name ||= begin
          value ||= self.name unless !self.name || self.name.empty?
          value.to_s.downcase if value
        end
    end
end
