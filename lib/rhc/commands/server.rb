require 'rhc/commands/base'

module RHC::Commands
  class Server < Base
    suppress_wizard

    summary "Display information about the status of the OpenShift service."
    description "Retrieves any open issues or notices about the operation of the OpenShift service and displays them in the order they were opened."
    def run
      say "Connected to #{openshift_server}"

      if openshift_server == 'openshift.redhat.com'
        status = decode_json(get("#{openshift_url}/app/status/status.json").body)
        open = status['open']

        (success 'All systems running fine' and return 0) if open.blank?

        open.each do |i|
          i = i['issue']
          say color("%-3s %s" % ["##{i['id']}", i['title']], :bold)
          items = i['updates'].map{ |u| [u['description'], date(u['created_at'])] }
          items.unshift ['Opened', date(i['created_at'])]
          table(items, :align => [nil,:right], :join => '  ').each{ |s| say "    #{s}" }
        end
        say "\n"
        warn pluralize(open.length, "open issue")

        open.length #exit with the count of open items
      else
        success "Using API version #{rest_client.api_version_negotiated}"
        0
      end
    end
  end
end
