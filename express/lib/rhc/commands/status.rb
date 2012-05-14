require 'rhc/commands/base'

module RHC::Commands
  class Status < Base
    def run
      say 'Check server status'
      # status = json(get('/app/status/status.json')
      # (success 'All systems running fine' and return 0) if status.issues.empty? or status.alerts.empty? 
      # table('Service alerts:', status.alerts) { |t| [t.message, t.time] })
      # table('Known issues:', status.issues) { |t| [t.message, t.time] })
      # 1
    end
  end
end
