require 'rhc/commands/base'

module RHC::Commands
  class Apps < Base
    summary "List all your applications"
    description "Display the list of applications that you own. Includes information about each application."
    def run
      domains = rest_client.domains

      info "In order to deploy applications, you must create a domain with 'rhc setup' or 'rhc create-domain'." and return 1 if domains.empty?

      applications = domains.map{ |d| d.applications(:include => :cartridges) }.flatten.sort

      applications.each{ |a| display_app(a, a.cartridges) }.blank? and
        info "No applications. Use 'rhc create-app'." and
        return 1

      success "You have #{applications.length} applications"
      0
    end
  end
end
