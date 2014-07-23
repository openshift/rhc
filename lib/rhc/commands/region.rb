require 'rhc/commands/base'

module RHC::Commands
  class Region < Base
    summary "Display the regions and zones available on the OpenShift server"
    default_action :list

    summary "List the regions and zones available on the OpenShift server"
    alias_action :"regions", :root_command => true
    def list
      regions = rest_client.regions

      raise RHC::NoRegionConfiguredException if regions.empty?
      
      paragraph{ say "Server #{options.server}" }

      regions.sort.each do |region|
        display_region(region)
      end

      paragraph{ say "To create an app in a specific region use 'rhc create-app <name> <cartridge> --region <region>'." }

      0
    end

  end
end
