require 'rhc/commands/base'

module RHC::Commands
  class Apps < Base
    summary "List all your applications"
    description "Display the list of applications that you own. Includes information about each application."
    option ['--mine'], "Display only applications you own"
    option ["-s", "--summary"], "Display a summary about the applications you own."
    option ["-v", "--verbose"], "Display additional details about the application's cartridges."

    def run
      applications = (options.mine ?
        rest_client.owned_applications(:include => :cartridges) :
        rest_client.applications(:include => :cartridges)).sort

      info "In order to deploy applications, you must create a domain with 'rhc setup' or 'rhc create-domain'." and return 1 if applications.empty? && rest_client.domains.empty?
      info "No applications. Use 'rhc create-app'." and return 1 if applications.nil? || applications.empty?
      info "You used the -v/--verbose and -s/--summary options together, but they are incompatible." and return 1 if options.summary && options.verbose

      if options.summary
        display_app_summary(applications)
      else
        applications.each{|a| display_app(a, a.cartridges, nil, options.verbose) }
      end

      success "You have#{options.mine ? '' : ' access to'} #{pluralize(applications.length, 'application')}."
      0
    end
  end
end
