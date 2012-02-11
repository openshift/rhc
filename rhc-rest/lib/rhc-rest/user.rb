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
    class User
      include Rest
      attr_reader :login
      def initialize(args)
        @login = args[:login] || args["login"]
        @links = args[:links] || args["links"]
      end

      #Add Key for this user
      def add_key(name, content, type)
        url = @@end_point + @links['ADD_KEY']['href']
        method =  @links['ADD_KEY']['method']
        payload = {:name => name, :type => type, :content => content}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Get all Key for this user
      def keys
        url = @@end_point + @links['LIST_KEYS']['href']
        method =  @links['LIST_KEYS']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      #Find Key by name
      def find_key(name)
        filtered = Array.new
        keys.each do |key|
        #TODO do a regex caomparison
          if key.name == name
          filtered.push(key)
          end
        end
        return filtered
      end
    end
  end
end