require 'rhc/commands/base'

module RHC::Commands
  class Server < Base
    def run
      status = decode_json(RestClient.get("https://#{openshift_server}/app/status/status.json").body)
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
    end
  end
end
