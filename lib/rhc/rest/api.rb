module RHC
  module Rest
    class Api < Base
      attr_reader :server_api_versions, :client_api_versions

      def initialize(client, preferred_api_versions=[])
        super(nil, client)

        # API version negotiation
        @server_api_versions = []
        debug "Client supports API versions #{preferred_api_versions.join(', ')}"
        @client_api_versions = preferred_api_versions
        @server_api_versions, @current_api_version, links = api_info({
          :url => client.url,
          :method => :get,
          :accept => :json,
          :no_auth => !RHC::Config['always_auth'],
        })
        debug "Server supports API versions #{@server_api_versions.join(', ')}"

        if api_version_negotiated
          debug "   Using API version #{api_version_negotiated}"
          unless client_api_version_current?
            debug "Client API version #{api_version_negotiated} is not current. Refetching API"
            # need to re-fetch API
            @server_api_versions, @current_api_version, links = api_info({
              :url => client.url,
              :method => :get,
              :accept => :json,
              :api_version => api_version_negotiated,
              :no_auth => !RHC::Config['always_auth'],
            })
          end
        else
          warn_about_api_versions
        end

        attributes['links'] = links

      rescue RHC::Rest::ResourceNotFoundException => e
        raise ApiEndpointNotFound.new(
          "The OpenShift server is not responding correctly.  Check "\
          "that '#{client.url}' is the correct URL for your server. "\
          "The server may be offline or misconfigured.")
      end

      ### API version related methods
      def api_version_match?
        ! api_version_negotiated.nil?
      end

      # return the API version that the server and this client can agree on
      def api_version_negotiated
        client_api_versions.reverse. # choose the last API version listed
          detect { |v| @server_api_versions.include? v }
      end

      def client_api_version_current?
        current_api_version == api_version_negotiated
      end

      def current_api_version
        @current_api_version
      end

      def warn_about_api_versions
        if !api_version_match?
          warn "WARNING: API version mismatch. This client supports #{client_api_versions.join(', ')} but
server at #{URI.parse(client.url).host} supports #{@server_api_versions.join(', ')}."
          warn "The client version may be outdated; please consider updating 'rhc'. We will continue, but you may encounter problems."
        end
      end

      protected
        include RHC::Helpers

      private
        # execute +req+ with RestClient, and return [server_api_versions, links]
        def api_info(req)
          client.request(req) do |response|
            json_response = ::RHC::Json.decode(response.content)
            [ json_response['supported_api_versions'], json_response['api_version'] || json_response['version'].to_f, json_response['data'] ]
          end
        end
    end
  end
end
