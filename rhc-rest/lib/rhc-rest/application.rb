# Copyright 2011 Red Hat, Inc.
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

module Rhc
  module Rest
    class Application
      include Rest
      attr_reader :domain_id, :name, :creation_time, :uuid, :aliases, :server_identity
      def initialize(args)
        @domain_id = args[:domain_id] || args["domain_id"]
        @name = args[:name] || args["name"]
        @creation_time = args[:creation_time] || args["creation_time"]
        @uuid = args[:uuid] || args["uuid"]
        @aliases = args[:aliases] || args["aliases"]
        @server_identity = args[:server_identity] || args["server_identity"]
        @links = args[:links] || args["links"]
      end

      #Add Cartridge
      def add_cartridge(name)
        logger.debug "Adding cartridge #{name}"
        url = @@end_point + @links['ADD_CARTRIDGE']['href']
        method =  @links['ADD_CARTRIDGE']['method']
        payload = {:name => name}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Get all Cartridge for this applications
      def cartridges
        logger.debug "Getting all cartridges for application #{self.name}"
        url = @@end_point + @links['LIST_CARTRIDGES']['href']
        method =  @links['LIST_CARTRIDGES']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      #Start Application
      def start
        logger.debug "Starting application #{self.name}"
        url = @@end_point + @links['START']['href']
        method =  @links['START']['method']
        payload = {:event=> "start"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Stop  Application
      def stop(force=false)
        logger.debug "Stopping application #{self.name} force-#{force}"
        url = @@end_point + @links['STOP']['href']
        method =  @links['STOP']['method']
        if force
          payload = {:event=> "force-stop"}
        else
          payload = {:event=> "stop"}
        end
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Restart Application
      def restart
        logger.debug "Restarting application #{self.name}"
        url = @@end_point + @links['RESTART']['href']
        method =  @links['RESTART']['method']
        payload = {:event=> "restart"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Delete Application
      def destroy
        logger.debug "Deleting application #{self.name}"
        url = @@end_point + @links['DELETE']['href']
        method =  @links['DELETE']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end
      alias :delete :destroy
    end
  end
end