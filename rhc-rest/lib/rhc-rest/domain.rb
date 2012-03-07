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
    class Domain
      include Rest
      attr_reader :namespace
      def initialize(args)
        @namespace = args[:namespace] || args["namespace"]
        @links = args[:links] || args["links"]
      end

      #Add Application to this domain
      def add_application(name, cartridge, scale=false)
        logger.debug "Adding application #{name} to domain #{self.namespace}"
        url = @@end_point + @links['ADD_APPLICATION']['href']
        method =  @links['ADD_APPLICATION']['method']
        payload = {:name => name, :cartridge => cartridge}
        if scale
          payload[:scale] = true
        end
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Get all Application for this domain
      def applications
        logger.debug "Getting all applications for domain #{self.namespace}"
        url = @@end_point + @links['LIST_APPLICATIONS']['href']
        method =  @links['LIST_APPLICATIONS']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      #Update Domain
      def update(new_namespace)
        logger.debug "Updating domain #{self.namespace} to #{new_namespace}"
        url = @@end_point + @links['UPDATE']['href']
        method =  @links['UPDATE']['method']
        payload = {:namespace => new_namespace}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end
      alias :save :update

      #Delete Domain
      def destroy(force=false)
        logger.debug "Deleting domain #{self.namespace}"
        url = @@end_point + @links['DELETE']['href']
        method =  @links['DELETE']['method']
        payload = {:force => force}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end
      alias :delete :destroy
    end
  end
end
