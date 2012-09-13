require "rhc/rest"

module RHCHelper
  
  class Sshkey
    extend Runnable
    extend Commandify
    
    class << self
      attr_accessor :sshkey_output, :exitcode
    end
    
    def self.list(*args)
      rhc_sshkey_list args
    end
    
    def self.show(*args)
      rhc_sshkey_show args
    end
    
    def self.add(*args)
      rhc_sshkey_add args
    end
    
    def self.remove(*args)
      rhc_sshkey_remove args
    end
  end
end