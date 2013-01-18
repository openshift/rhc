module RHC::Commands
  class Server < Base
    suppress_wizard

    summary "Display information about the status of the OpenShift service."
    description <<-DESC
      Retrieves any open issues or notices about the operation of the
      OpenShift service and displays them in the order they were opened.

      When connected to an OpenShift Enterprise server, will only display
      the version of the API that it is connecting to.
      DESC
    def run
      say "Connected to #{openshift_server}"

      if openshift_online_server?
        #status = decode_json(get("#{openshift_url}/app/status/status.json").body)
        status = rest_client.request(:method => :get, :url => "#{openshift_url}/app/status/status.json", :lazy_auth => true){ |res| decode_json(res.content) }
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
