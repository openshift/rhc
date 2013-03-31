module RHC::Commands
  class Account < Base
    suppress_wizard

    summary "Display details about your OpenShift account"
    description <<-DESC
      Shows who you are logged in to the server as and the capabilities
      available to you on this server.

      To access more details about your account please visit the website.
      DESC
    def run
      user = rest_client.user

      say_table nil, get_properties(user, :login, :plan_id, :consumed_gears, :max_gears) + get_properties(user.capabilities, :gear_sizes).unshift(['Server:', openshift_server]) << ['SSL Certificates Supported:', user.capabilities.private_ssl_certificates ? 'yes' : 'no'], :delete => true

      if openshift_online_server?
      else
      end

      0
    end
  end
end
