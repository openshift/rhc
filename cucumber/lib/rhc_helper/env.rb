require "rhc/rest"

module RHCHelper

  class Env
    extend Runnable
    extend Commandify

    class << self
      attr_accessor :env_output, :exitcode
    end

    def self.list(*args)
      rhc_env_list args
    end

    def self.show(*args)
      rhc_env_show args
    end

    def self.set(*args)
      rhc_env_set args
    end

    def self.unset(*args)
      rhc_env_unset args
    end
  end
end
