require 'dnsruby'
require 'rhc/rest'

module RHCHelper
  #
  # A class to help maintain the state from rhc calls
  #
  class Domain
    extend Runnable
    extend Commandify
    include Dnsruby

    class << self
      attr_reader :domain_output, :domain_show_output, :exitcode
    end

    def self.unique_namespace(prefix)
      namepace = nil
      begin
        # Loop until we find a unique namespace
        chars = ("1".."9").to_a
        namespace = prefix + Array.new(8, '').collect{chars[rand(chars.size)]}.join

       end while reserved?(namespace)
       namespace
    end

    def self.create_if_needed(prefix="test")
      unless $namespace
        $namespace = unique_namespace(prefix)
        # Create the domain
        rhc_domain_create

        # Write the new domain to a file in the temp directory
        File.open(File.join(RHCHelper::TEMP_DIR, 'namespace'), 'w') do |f|
          f.write($namespace)
        end
      end
    end

    def self.create
      rhc_domain_create
    end

    def self.delete
      rhc_domain_delete
      $namespace = nil
      # Write the new domain to a file in the temp directory
      namespace_file = File.join(RHCHelper::TEMP_DIR, 'namespace')
      File.delete(namespace_file) if File.exists?(namespace_file)
    end

    def self.update(prefix="update")
      $old_namespace = $namespace
      $namespace = unique_namespace(prefix)
      rhc_domain_update

      namespace_file = File.join(RHCHelper::TEMP_DIR, 'namespace')
      if @exitcode == 0
        # Write the new domain to a file in the temp directory
        File.open(namespace_file, 'w') do |f|
          f.write($namespace)
        end
      else
        $namespace = old_namespace
      end
    end

    def self.reserved?(namespace=$namespace)
      # If we get a response, then the namespace is reserved
      # An exception means that it is available
      begin
        Dnsruby::Resolver.new.query("#{namespace}.#{$domain}", Dnsruby::Types::TXT)
        return true
      rescue
        return false
      end
    end
  end
end
