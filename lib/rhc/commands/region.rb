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

      paragraph do
        if regions.find{|r| r.allow_selection?}.blank?
          warn "Regions can't be explicitly provided by users and will be automatically selected by the system."
        else
          say "To create an app in a specific region use 'rhc create-app <name> <cartridge> --region <region>'."
        end
      end
      0
    end

  end
end
