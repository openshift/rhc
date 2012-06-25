require 'dnsruby'
require 'rhc-rest'

module RHCHelper
  #
  # A class to help maintain the state from rhc calls
  #
  class Domain
    extend Runnable
    extend Commandify
    include Dnsruby

    def self.create_if_needed(prefix="test")
      unless $namespace
        loop do
          # Loop until we find a unique namespace
          chars = ("1".."9").to_a
          namespace = prefix + Array.new(8, '').collect{chars[rand(chars.size)]}.join

          # No retries on reservation check
          unless reserved?(namespace)
            # Set the global namespace
            $namespace = namespace

            # Create the domain
            rhc_domain_create

            # Write the new domain to a file in the temp directory
            File.open(File.join(RHCHelper::TEMP_DIR, 'namespace'), 'w') do |f| 
              f.write(namespace)
            end

            break
          end
        end
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
