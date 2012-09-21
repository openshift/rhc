require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/rest'

Spec::Runner.configure do |configuration|
  include(RestSpecHelper)
end

# We have to make an object to test the RHC::Rest module
class RHCRest
  include RHC::Rest
end

module MockRestResponse
  def set_code(error_code)
    @error_code = error_code
  end
  def code
    @error_code
  end
end

module RHC
  include RestSpecHelper

  describe Rest do
    subject{ RHCRest.new }

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
          subject.parse_response(json_response).should have_same_attributes_as(object)
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
          subject.parse_response(json_response).should have_same_attributes_as(app_obj)
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
          subject.parse_response(json_response).length.should equal(2)
          subject.parse_response(json_response)[0].should have_same_attributes_as(app_obj_1)
          subject.parse_response(json_response)[1].should have_same_attributes_as(app_obj_2)
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
          subject.parse_response(json_response).should have_same_attributes_as(cart_obj)
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
          subject.parse_response(json_response).length.should equal(2)
          subject.parse_response(json_response)[0].should have_same_attributes_as(cart_obj_1)
          subject.parse_response(json_response)[1].should have_same_attributes_as(cart_obj_2)
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
          subject.parse_response(json_response).should have_same_attributes_as(dom_obj)
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
          subject.parse_response(json_response).length.should equal(2)
          subject.parse_response(json_response)[0].should have_same_attributes_as(dom_obj_1)
          subject.parse_response(json_response)[1].should have_same_attributes_as(dom_obj_2)
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
          subject.parse_response(json_response).should have_same_attributes_as(key_obj)
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
          subject.parse_response(json_response).length.should equal(2)
          subject.parse_response(json_response)[0].should have_same_attributes_as(key_obj_1)
          subject.parse_response(json_response)[1].should have_same_attributes_as(key_obj_2)
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
          subject.parse_response(json_response).should have_same_attributes_as(user_obj)
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

      context "with a request timeout" do
        before do
          stub_request(:get, mock_href).to_timeout
        end
        it "raises a resource access exception error" do
          request = RestClient::Request.new(:url     => mock_href,
                                            :method  => 'get',
                                            :headers => {:accept => :json}
                                            )
          lambda { subject.request(request) }.should raise_error(RHC::Rest::TimeoutException, "Connection to server timed out. It is possible the operation finished without being able to report success. Use 'rhc domain show' or 'rhc app status' to check the status of your applications.")
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
      context "with a 400 response" do
        it "raises a client error" do
          mock_resp  = { :messages => [{ :severity => 'error', :text => 'mock error message' }] }
          json_data = RHC::Json.encode(mock_resp)
          json_data.extend(MockRestResponse)
          json_data.set_code(400)
          lambda { subject.process_error_response(json_data) }.should raise_error(RHC::Rest::ClientErrorException, 'mock error message')
        end
      end

      context "with a 401 response" do
        it "raises an 'unauthorized exception' error" do
          json_data = RHC::Json.encode({})
          json_data.extend(MockRestResponse)
          json_data.set_code(401)

          lambda { subject.process_error_response(json_data) }.should raise_error(RHC::Rest::UnAuthorizedException, 'Not authenticated')
        end
      end

      context "with a 403 response" do
        it "raises a 'request denied' error" do
          mock_resp  = { :messages => [{ :severity => 'error', :text => 'mock error message' }] }
          json_data  = RHC::Json.encode(mock_resp)
          json_data.extend(MockRestResponse)
          json_data.set_code(403)
          lambda { subject.process_error_response(json_data) }.should raise_error(RHC::Rest::RequestDeniedException, 'mock error message')
        end
      end

      context "with a 404 response" do
        it "raises a 'resource not found' error" do
          mock_resp  = { :messages => [{ :severity => 'error', :text => 'mock error message' }] }
          json_data  = RHC::Json.encode(mock_resp)
          json_data.extend(MockRestResponse)
          json_data.set_code(404)
          lambda { subject.process_error_response(json_data) }.should raise_error(RHC::Rest::ResourceNotFoundException, 'mock error message')
        end
      end

      context "with a 409 response" do
        it "raises a validation error" do
          mock_resp  = { :messages => [{ :severity => 'error', :text => 'mock error message' }] }
          json_data  = RHC::Json.encode(mock_resp)
          json_data.extend(MockRestResponse)
          json_data.set_code(409)
          lambda { subject.process_error_response(json_data) }.should raise_error(RHC::Rest::ValidationException, 'mock error message')
        end
      end

      context "with a 422 response" do
        it "raises a validation error" do
          mock_resp  = { :messages => [{ :severity => 'error', :text => 'mock error message' }] }
          json_data  = RHC::Json.encode(mock_resp)
          json_data.extend(MockRestResponse)
          json_data.set_code(422)
          lambda { subject.process_error_response(json_data) }.should raise_error(RHC::Rest::ValidationException, 'mock error message')
        end
      end

      context "with multiple 422 responses" do
        it "raises a validation error with concatenated messages" do
          mock_resp  = { :messages => [{ :field => 'error', :text => 'mock error message 1' },
                                       { :field => 'error', :text => 'mock error message 2' }] }
          json_data  = RHC::Json.encode(mock_resp)
          json_data.extend(MockRestResponse)
          json_data.set_code(422)
          lambda { subject.process_error_response(json_data) }.should raise_error(RHC::Rest::ValidationException, 'mock error message 1 mock error message 2')
        end
      end

      context "with a 500 response" do
        it "raises a server error" do
          mock_resp  = { :messages => [{ :severity => 'error', :text => 'mock error message' }] }
          json_data  = RHC::Json.encode(mock_resp)
          json_data.extend(MockRestResponse)
          json_data.set_code(500)
          lambda { subject.process_error_response(json_data) }.should raise_error(RHC::Rest::ServerErrorException, 'mock error message')
        end
      end

      context "with a 503 response" do
        it "raises a 'service unavailable' error" do
          mock_resp  = { :messages => [{ :severity => 'error', :text => 'mock error message' }] }
          json_data  = RHC::Json.encode(mock_resp)
          json_data.extend(MockRestResponse)
          json_data.set_code(503)
          lambda { subject.process_error_response(json_data) }.should raise_error(RHC::Rest::ServiceUnavailableException, 'mock error message')
        end
      end

      context "with an unhandled response code" do
        it "raises a resource access error" do
          mock_resp  = { :messages => [{ :severity => 'error', :text => 'mock error message' }] }
          json_data  = RHC::Json.encode(mock_resp)
          json_data.extend(MockRestResponse)
          json_data.set_code(999)
          lambda { subject.process_error_response(json_data) }.should raise_error(RHC::Rest::ResourceAccessException, 'Server returned error code with no output: 999')
        end
      end
    end
  end
end
