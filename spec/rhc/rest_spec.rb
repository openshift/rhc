require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/rest'

class RHCRest
  include RHC::Rest
  def debug?
    false
  end
  def debug(*args)
    raise "Unchecked debug"
  end
end

module MockRestResponse
  attr_accessor :code, :read
end


describe RHC::Rest::Cartridge do
  context 'with a name' do
    before{ subject.name = 'foo' }
    its(:display_name){ should == 'foo' }

    context 'when display name is present' do
      before{ subject.display_name = 'bar' }
      its(:display_name){ should == 'bar' }
    end
  end
end

module RHC

  describe Rest do
    subject{ RHC::Rest::Client.new }

    # logger function
    describe "#logger" do
      it "establishes a logger" do
        logger = Logger.new(STDOUT)
        subject.logger.should have_same_attributes_as(logger)
      end
    end

    # parse_response function
    describe "#parse_response" do
      context "with no response type" do
        let(:object) {{ :links => { :foo => 'bar' } }}
        it "deserializes to the encapsulated data" do
          json_response = { :data => object }.to_json
          subject.send(:parse_response, json_response).should have_same_attributes_as(object)
        end
      end

      context "with an application" do
        let(:object) {{
            :domain_id       => 'test_domain',
            :name            => 'test_app',
            :creation_time   => '0000-00-00 00:00:00 -0000',
            :uuid            => 'test_app_1234',
            :aliases         => ['app_alias_1', 'app_alias_2'],
            :server_identity => 'test_server',
            :links           => { :foo => 'bar' }
          }}
        it "deserializes to an application" do
          json_response = { :type => 'application', :data => object, :messages => [{'text' => 'test message'}]}.to_json
          app_obj       = RHC::Rest::Application.new(object)
          subject.send(:parse_response, json_response).should have_same_attributes_as(app_obj)
        end
      end

      context "with two applications" do
        let(:object) {[{ :domain_id       => 'test_domain',
                         :name            => 'test_app',
                         :creation_time   => '0000-00-00 00:00:00 -0000',
                         :uuid            => 'test_app_1234',
                         :aliases         => ['app_alias_1', 'app_alias_2'],
                         :server_identity => 'test_server',
                         :links           => { :foo => 'bar' }
                       },
                       { :domain_id       => 'test_domain_2',
                         :name            => 'test_app_2',
                         :creation_time   => '0000-00-00 00:00:00 -0000',
                         :uuid            => 'test_app_2_1234',
                         :aliases         => ['app_alias_3', 'app_alias_4'],
                         :server_identity => 'test_server_2',
                         :links           => { :foo => 'bar' }
                       }]
        }
        it "deserializes to a list of applications" do
          json_response = { :type => 'applications', :data => object }.to_json
          app_obj_1     = RHC::Rest::Application.new(object[0])
          app_obj_2     = RHC::Rest::Application.new(object[1])
          subject.send(:parse_response, json_response).length.should equal(2)
          subject.send(:parse_response, json_response)[0].should have_same_attributes_as(app_obj_1)
          subject.send(:parse_response, json_response)[1].should have_same_attributes_as(app_obj_2)
        end
      end

      context "with a cartridge" do
        let(:object) {{
            :name  => 'test_cartridge',
            :type  => 'test_cartridge_type',
            :links => { :foo => 'bar' }
          }}

        it "deserializes to a cartridge" do
          json_response = { :type => 'cartridge', :data => object }.to_json
          cart_obj      = RHC::Rest::Cartridge.new(object)
          subject.send(:parse_response, json_response).should have_same_attributes_as(cart_obj)
        end
      end

      context "with two cartridges" do
        let(:object) {[{ :name  => 'test_cartridge',
                         :type  => 'test_cartridge_type',
                         :links => { :foo => 'bar' }
                       },
                       { :name  => 'test_cartridge_2',
                         :type  => 'test_cartridge_type_2',
                         :links => { :foo => 'bar' }
                       }
                      ]}

        it "deserializes to a list of cartridges" do
          json_response = { :type => 'cartridges', :data => object }.to_json
          cart_obj_1    = RHC::Rest::Cartridge.new(object[0])
          cart_obj_2    = RHC::Rest::Cartridge.new(object[1])
          subject.send(:parse_response, json_response).length.should equal(2)
          subject.send(:parse_response, json_response)[0].should have_same_attributes_as(cart_obj_1)
          subject.send(:parse_response, json_response)[1].should have_same_attributes_as(cart_obj_2)
        end
      end

      context "with a domain" do
        let(:object) {{
            :id    => 'test_domain',
            :links => { :foo => 'bar' }
          }}

        it "deserializes to a domain" do
          json_response = { :type => 'domain', :data => object }.to_json
          dom_obj       = RHC::Rest::Domain.new(object)
          subject.send(:parse_response, json_response).should have_same_attributes_as(dom_obj)
        end
      end

      context "with two domains" do
        let(:object) {[{ :id    => 'test_domain',
                         :links => { :foo => 'bar' }
                       },
                       { :id    => 'test_domain_2',
                         :links => { :foo => 'bar' }
                       }
                      ]}

        it "deserializes to a list of domains" do
          json_response = { :type => 'domains', :data => object }.to_json
          dom_obj_1     = RHC::Rest::Domain.new(object[0])
          dom_obj_2     = RHC::Rest::Domain.new(object[1])
          subject.send(:parse_response, json_response).length.should equal(2)
          subject.send(:parse_response, json_response)[0].should have_same_attributes_as(dom_obj_1)
          subject.send(:parse_response, json_response)[1].should have_same_attributes_as(dom_obj_2)
        end
      end

      context "with a key" do
        let(:object) {{
            :name    => 'test_key',
            :type    => 'test_key_type',
            :content => 'test_key_content',
            :links   => { :foo => 'bar' }
          }}

        it "deserializes to a key" do
          json_response = { :type => 'key', :data => object }.to_json
          key_obj       = RHC::Rest::Key.new(object)
          subject.send(:parse_response, json_response).should have_same_attributes_as(key_obj)
        end
      end

      context "with two keys" do
        let(:object) {[{ :name    => 'test_key',
                         :type    => 'test_key_type',
                         :content => 'test_key_content',
                         :links   => { :foo => 'bar' }
                       },
                       { :name    => 'test_key_2',
                         :type    => 'test_key_type_2',
                         :content => 'test_key_content_2',
                         :links   => { :foo => 'bar' }
                       }
                      ]}

        it "deserializes to a list of keys" do
          json_response = { :type => 'keys', :data => object }.to_json
          key_obj_1     = RHC::Rest::Key.new(object[0])
          key_obj_2     = RHC::Rest::Key.new(object[1])
          subject.send(:parse_response, json_response).length.should equal(2)
          subject.send(:parse_response, json_response)[0].should have_same_attributes_as(key_obj_1)
          subject.send(:parse_response, json_response)[1].should have_same_attributes_as(key_obj_2)
        end
      end

      context "with a user" do
        let(:object) {{
            :login => 'test_user',
            :links => { :foo => 'bar' }
          }}

        it "deserializes to a user" do
          json_response = { :type => 'user', :data => object }.to_json
          user_obj      = RHC::Rest::User.new(object)
          subject.send(:parse_response, json_response).should have_same_attributes_as(user_obj)
        end
      end
    end

    # request function
    describe "#request" do
      context "with a successful request" do
        let(:object) {{
            :type => 'domain',
            :data => {
              :id    => 'test_domain',
              :links => { :foo => 'bar' }
            }}}
        before do
          return_data = {
            :body    => object.to_json,
            :status  => 200,
            :headers => { 'Set-Cookie' => "rh_sso=test_ssh_cookie" }
          }
          stub_request(:get, mock_href).to_return(return_data)
        end

        it "sends the response to be deserialized" do
          dom_obj = RHC::Rest::Domain.new(object)
          request = RestClient::Request.new(:url     => mock_href,
                                            :method  => 'get',
                                            :headers => { :accept => :json },
                                            :payload => {},
                                            :timeout => 300
                                            )
          subject.request(request).should have_same_attributes_as(dom_obj)
        end
      end

      context "with a nil response" do
        before do
          return_data = {
            :body    => nil,
            :status  => 200,
            :headers => { 'Set-Cookie' => "rh_sso=test_ssh_cookie" }
          }
          stub_request(:get, mock_href).to_return(return_data)
        end
        it "throws an error" do
          request = RestClient::Request.new(:url     => mock_href,
                                            :method  => 'get',
                                            :headers => {:accept => :json}
                                            )
          lambda { subject.request(request) }.should raise_error(RHC::Rest::ResourceAccessException, 'Failed to access resource: unexpected nil')
        end
      end

      context "with a 204 (No Content) response" do
        before do
          return_data = {
            :body    => nil,
            :status  => 204,
            :headers => { 'Set-Cookie' => "rh_sso=test_ssh_cookie" }
          }
          stub_request(:get, mock_href).to_return(return_data)
        end
        it "quietly exits" do
          request = RestClient::Request.new(:url     => mock_href,
                                            :method  => 'get',
                                            :headers => {:accept => :json}
                                            )
          subject.request(request).should equal(nil)
        end
      end

      context "with a 502 (Bad Gateway) error" do
        before{ stub_request(method, mock_href).to_return(:status => 502) }
        let(:req){ RestClient::Request.new(:url => mock_href, :method => method) }
        let(:method){ :get }

        it("should make two requests"){ subject.request(req) rescue nil; WebMock.should have_requested(method, mock_href).twice }
        it{ expect{ subject.request(req) }.should raise_error(RHC::Rest::ConnectionException, /communicating with the server.*temporary/i) }

        context "on a POST request" do
          let(:method){ :post }

          it("should make one request"){ subject.request(req) rescue nil; WebMock.should have_requested(method, mock_href).once }
          it{ expect{ subject.request(req) }.should raise_error(RHC::Rest::ConnectionException, /communicating with the server.*temporary/i) }
        end
      end

      context "with a request timeout" do
        before do
          stub_request(:get, mock_href).to_timeout
        end
        it "raises a resource access exception error" do
          request = RestClient::Request.new(:url     => mock_href,
                                            :method  => 'get',
                                            :headers => {:accept => :json}
                                            )
          lambda { subject.request(request) }.should raise_error(RHC::Rest::TimeoutException, /Connection to server timed out. It is possible/)
        end
      end

      context "with a broken server connection" do
        before do
          stub_request(:get, mock_href).to_raise(RestClient::ServerBrokeConnection.new('Lost Server Connection'))
        end
        it "raises a resource access exception error" do
          request = RestClient::Request.new(:url     => mock_href,
                                            :method  => 'get',
                                            :headers => {:accept => :json}
                                            )
          lambda { subject.request(request) }.should raise_error(RHC::Rest::ConnectionException, 'Connection to server got interrupted: Lost Server Connection')
        end
      end

      context "with an unverified SSL certificate" do
        before do
          stub_request(:get, mock_href).to_raise(RestClient::SSLCertificateNotVerified.new('Unverified SSL Certificate'))
        end
        it "raises a resource access exception error" do
          request = RestClient::Request.new(:url     => mock_href,
                                            :method  => 'get',
                                            :headers => {:accept => :json}
                                            )
          lambda { subject.request(request) }.should raise_error(RHC::Rest::ResourceAccessException, 'Failed to access resource: Unverified SSL Certificate')
        end
      end

      context "with a socket error" do
        before{ stub_request(:get, mock_href).to_raise(SocketError) }
        it "raises a resource access exception error" do
          expect{ subject.request(:url => mock_href, :method  => 'get', :headers => {:accept => :json}) }.should raise_error(RHC::Rest::ConnectionException, /unable to connect to the server/i)
        end
      end

      context "with a generic exception error" do
        before do
          stub_request(:get, mock_href).to_raise(Exception.new('Generic Error'))
        end

        it "raises a resource access exception error" do
          request = RestClient::Request.new(:url     => mock_href,
                                            :method  => 'get',
                                            :headers => {:accept => :json}
                                            )
          lambda { subject.request(request) }.should raise_error(RHC::Rest::ResourceAccessException, 'Failed to access resource: Generic Error')
        end
      end

      context "with a specific error response" do
        before do
          return_data = {
            :body    => nil,
            :status  => 401,
            :headers => { 'Set-Cookie' => "rh_sso=test_ssh_cookie" }
          }
          stub_request(:get, mock_href).to_return(return_data)
        end

        it "passes the response off for interpretation" do
          request = RestClient::Request.new(:url     => mock_href,
                                            :method  => 'get',
                                            :headers => {:accept => :json}
                                            )
          lambda { subject.request(request) }.should raise_error(RHC::Rest::UnAuthorizedException, 'Not authenticated')
        end
      end
    end

    # process_error_response function
    describe "#process_error_response" do
      let(:json){ nil }
      let(:body){ "<html><body>Something failed</body></html>" }
      let(:code){ nil }
      def response
        (response = {}).extend(MockRestResponse)
        response.code = code
        response.read = json ? RHC::Json.encode(json) : body
        response
      end

      context "with a 400 response" do
        let(:code){ 400 }

        it "raises a generic server error" do
          lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ServerErrorException)
        end

        context "with a formatted JSON response" do
          let(:json){ {:messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a client error" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ClientErrorException, 'mock error message')
          end
        end
      end

      context "with a 401 response" do
        let(:code){ 401 }
        let(:json){ {} }
        it "raises an 'unauthorized exception' error" do
          lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::UnAuthorizedException, 'Not authenticated')
        end
      end

      context "with a 403 response" do
        let(:code){ 403 }

        it "raises a request denied error" do
          lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::RequestDeniedException)
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a 'request denied' error" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::RequestDeniedException, 'mock error message')
          end
        end
      end

      context "with a 404 response" do
        let(:code){ 404 }

        it "raises a Not Found error" do
          lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ResourceNotFoundException)
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a 'resource not found' error" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ResourceNotFoundException, 'mock error message')
          end
        end
      end

      context "with a 409 response" do
        let(:code){ 409 }

        it "raises a generic server error" do
          lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ServerErrorException)
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a validation error" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ValidationException, 'mock error message')
          end
        end
      end

      context "with a 422 response" do
        let(:code){ 422 }

        it "raises a generic server error" do
          lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ServerErrorException)
        end

        context "with a single JSON message" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a validation error" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ValidationException, 'mock error message')
          end
        end

        context "with an empty JSON response" do
          let(:json){ {} }
          it "raises a validation error" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ValidationException, 'Not valid')
          end
        end

        context "with multiple JSON messages" do
          let(:json){ { :messages => [{ :field => 'error', :text => 'mock error message 1' },
                                       { :field => 'error', :text => 'mock error message 2' }] } }
          it "raises a validation error with concatenated messages" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ValidationException, 'mock error message 1 mock error message 2')
          end
        end
      end

      context "with a 500 response" do
        let(:code){ 500 }

        it "raises a generic server error" do
          lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ServerErrorException, /server did not respond correctly.*verify that you can access the OpenShift server/i)
        end

        context "when proxy is set" do
          before{ RestClient.should_receive(:proxy).twice.and_return('http://foo.com') }
          it "raises a generic server error with the proxy URL" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ServerErrorException, /foo\.com/i)
          end
        end

        context "when request url is present" do
          it "raises a generic server error with the request URL" do
            lambda { subject.send(:process_error_response, response, 'foo.bar') }.should raise_error(RHC::Rest::ServerErrorException, /foo\.bar/i)
          end
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a server error" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ServerErrorException, 'mock error message')
          end
        end
      end

      context "with a 503 response" do
        let(:code){ 503 }

        it "raises a 'service unavailable' error" do
          lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ServiceUnavailableException)
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a 'service unavailable' error" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ServiceUnavailableException, 'mock error message')
          end
        end
      end

      context "with an unhandled response code" do
        let(:code){ 999 }

        it "raises a generic server error" do
          lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ServerErrorException)
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a resource access error" do
            lambda { subject.send(:process_error_response, response) }.should raise_error(RHC::Rest::ServerErrorException, 'Server returned an unexpected error code: 999')
          end
        end
      end
    end
  end
end
