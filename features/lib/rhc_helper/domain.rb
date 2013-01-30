require 'dnsruby'
require 'rhc/rest'

module RHCHelper
  #
  # A class to help maintain the state from rhc calls
  #
  class Domain
    extend Runnable
    extend Commandify
    extend API
    include Dnsruby

    class << self
      attr_reader :domain_output, :domain_show_output, :exitcode
    end

    def self.unique_namespace(prefix)
      # TODO:  Due to DNS changes with the model refactor,
      #        the namespace is not checked here - see #reserved?
      chars = ("1".."9").to_a
      prefix + Array.new(8, '').collect{chars[rand(chars.size)]}.join
    end

    def self.create_if_needed(prefix="test")
      unless $namespace
        client = new_client
        domain = client.domains.first
        if domain
          $namespace = domain.id
        else
          $namespace = unique_namespace(prefix)
          # Create the domain
          rhc_domain_create
        end
      end
    end

    def self.create
      rhc_domain_create
    end

    def self.delete
      rhc_domain_delete
      $namespace = nil
    end

    def self.update(prefix="update")
      $old_namespace = $namespace
      $namespace = unique_namespace(prefix)
      rhc_domain_update

      if @exitcode == 0
      else
        $namespace = $old_namespace
      end
    end

    def self.reserved?(namespace=$namespace)
      # With the recent model refactoring, we no longer create
      # TXT DNS records.
      # Here, we return 'true', since this is the only code that is
      # used in 'Then' clauses of 2 Cucumber scenarios.
      true
    end
  end
end
