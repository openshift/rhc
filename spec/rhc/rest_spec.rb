require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/rest'

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

describe RHC::Rest::Domain do
  subject{ RHC::Rest::Client.new(:server => mock_uri) }
  let(:user_auth){ nil }
  let(:domain) { subject.domains.first }
  context "against a 1.2 server" do
    before{ stub_api_v12; stub_one_domain('bar') }
    before do 
      stub_api_request(:post, 'broker/rest/domains/bar/applications', false).
        with(:body => {:name => 'foo', :cartridge => 'bar'}.to_json).
        to_return(:status => 201, :body => {:type => 'application', :data => {:id => '1'}}.to_json)
    end

    it{ domain.add_application('foo', :cartridges => ['bar']).should be_true }
    it{ expect{ domain.add_application('foo', :cartridges => ['bar', 'other']) }.to raise_error(RHC::Rest::MultipleCartridgeCreationNotSupported) }
    it{ expect{ domain.add_application('foo', :initial_git_url => 'a_url') }.to raise_error(RHC::Rest::InitialGitUrlNotSupported) }
    it{ expect{ domain.add_application('foo', :cartridges => [{:url => 'a_url'}]) }.to raise_error(RHC::Rest::DownloadingCartridgesNotSupported) }
    it{ domain.add_application('foo', :cartridges => 'bar').should be_true }
    it{ domain.add_application('foo', :cartridge => 'bar').should be_true }
    it{ domain.add_application('foo', :cartridge => ['bar']).should be_true }
  end
  context "against a server that supports initial git urls and downloaded carts" do
    let(:cartridges){ ['bar'] }
    before{ stub_api; stub_one_domain('bar', [{:name => 'initial_git_url'},{:name => 'cartridges[][url]'}]) }
    before do 
      stub_api_request(:post, 'broker/rest/domains/bar/applications', false).
        with(:body => {:name => 'foo', :cartridges => cartridges}.to_json).
        to_return(:status => 201, :body => {:type => 'application', :data => {:id => '1'}}.to_json)
    end

    it{ domain.add_application('foo', :cartridges => ['bar']).should be_true }
    it{ domain.add_application('foo', :cartridges => 'bar').should be_true }
    it{ domain.add_application('foo', :cartridge => 'bar').should be_true }
    it{ domain.add_application('foo', :cartridge => ['bar']).should be_true }

    context "with multiple cartridges" do
      let(:cartridges){ ['bar'] }
      it{ domain.add_application('foo', :cartridges => cartridges).should be_true }
      it{ domain.add_application('foo', :cartridge => cartridges).should be_true }
    end

    context "with a url" do
      before do
        stub_api_request(:post, 'broker/rest/domains/bar/applications', false).
          with(:body => {:name => 'foo', :initial_git_url => 'a_url', :cartridges => []}.to_json).
          to_return(:status => 201, :body => {:type => 'application', :data => {:id => '1'}}.to_json)
      end
      it{ domain.add_application('foo', :initial_git_url => 'a_url').should be_true }
    end

    context "with a cartridge url" do
      before do
        stub_api_request(:post, 'broker/rest/domains/bar/applications', false).
          with(:body => {:name => 'foo', :cartridges => [{:url => 'a_url'}]}.to_json).
          to_return(:status => 201, :body => {:type => 'application', :data => {:id => '1'}}.to_json)
      end
      it{ domain.add_application('foo', :cartridges => [{:url => 'a_url'}]).should be_true }
      it{ domain.add_application('foo', :cartridge => RHC::Rest::Cartridge.for_url('a_url')).should be_true }
      it{ domain.add_application('foo', :cartridge => [{'url' => 'a_url'}]).should be_true }
    end      
  end
end

module RHC

  describe Rest do
    subject{ RHC::Rest::Client.new }

    describe "#default_verify_callback" do
      def invoked_with(is_ok, ctx)
        subject.send(:default_verify_callback).call(is_ok, ctx)
      end
      it{ invoked_with(true, nil).should be_true }

      it{ expect{ invoked_with(false, nil) }.to raise_error(NoMethodError) }

      context "with a self signed cert" do
        it{ invoked_with(false, stub(:current_cert => stub(:issuer => '1', :subject => stub(:cmp => 0)))).should be_false }
        after{ subject.send(:self_signed?).should be_true }
      end

      context "with an intermediate signed cert" do
        it{ invoked_with(false, stub(:current_cert => stub(:issuer => '2', :subject => stub(:cmp => 1)), :error => 1, :error_string => 'a')).should be_false }
        after{ subject.send(:self_signed?).should be_false }
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

    describe "#new_request" do
      it{ subject.send(:new_request, :api_version => 2.0).last[4]['accept'].should == 'application/json;version=2.0' }
      it{ subject.send(:new_request, :headers => {:accept => :xml}, :api_version => 2.0).last[4]['accept'].should == 'application/xml;version=2.0' }
      context "with the default api version" do
        before{ subject.should_receive(:current_api_version).and_return('1.0') }
        it{ subject.send(:new_request, {}).last[4]['accept'].should == 'application/json;version=1.0' }
      end
    end

    # request function
    describe "#request" do
      let(:response){ lambda { subject.request(request) } }
      let(:request){ {:url => mock_href, :method  => method, :headers => {:accept => :json} } }
      let(:method){ :get }

      if HTTPClient::SSLConfig.method_defined? :ssl_version
        context "when an invalid ssl version is passed, OpenSSL should reject us" do
          let(:request){ {:url => "https://openshift.redhat.com", :method => :get, :ssl_version => :SSLv3_server} }
          before{ WebMock.allow_net_connect! }
          it("fails to call openssl"){ response.should raise_error(RHC::Rest::SSLConnectionFailed, /called a function you should not call/) }
          after{ WebMock.disable_net_connect! }
        end
      end

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
          stub_request(:get, mock_href).with{ |req| req.headers['Accept'].should == 'application/json;version=1.0' }.to_return(return_data)
        end

        it "sends the response to be deserialized" do
          dom_obj = RHC::Rest::Domain.new(object)
          subject.request(request.merge(:payload => {}, :api_version => '1.0', :timeout => 300)).should have_same_attributes_as(dom_obj)
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
          response.should raise_error(RHC::Rest::ConnectionException, 'An unexpected error occured: unexpected nil')
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
          response.call.should equal(nil)
        end
      end

      context "with a 502 (Bad Gateway) error" do
        before{ stub_request(method, mock_href).to_return(:status => 502) }

        context "on a GET request" do
          it("repeats the call"){ response.should raise_error(RHC::Rest::ConnectionException, /communicating with the server.*temporary/i) }
          after{ WebMock.should have_requested(method, mock_href).twice }
        end

        context "on a POST request" do
          let(:method){ :post }

          it("does not repeat the call"){ response.should raise_error(RHC::Rest::ConnectionException, /communicating with the server.*temporary/i) }
          after{ WebMock.should have_requested(method, mock_href).once }
        end
      end

      context "with a GET request" do
        it "serializes payload as query parameters" do
          stub_request(:get, mock_href).with(:query => {:test => 1, :bar => 2}).to_return(:status => 204)
          subject.request(request.merge(:payload => {:test => '1', :bar => 2})).should be_nil
        end
      end
      context "with a POST request" do
        let(:method){ :post }
        it "serializes payload as urlencoded body parameters" do
          stub_request(method, mock_href).
            with(:headers => {:accept => 'application/json', :content_type => 'application/json'}, 
                 :body => {:test => '1', :bar => 2}.to_json).
            to_return(:status => 204)
          subject.request(request.merge(:payload => {:test => '1', :bar => 2})).should be_nil
        end
      end

      context "with a request timeout" do
        before{ stub_request(:get, mock_href).to_timeout }
        it{ response.should raise_error(RHC::Rest::TimeoutException, /Connection to server timed out. It is possible/) }
      end

      context "with a broken server connection" do
        before{ stub_request(:get, mock_href).to_raise(EOFError.new('Lost Server Connection')) }
        it{ response.should raise_error(RHC::Rest::ConnectionException, 'Connection to server got interrupted: Lost Server Connection') }
      end

      #FIXME: the type of this exception should be a subclass of CertificateValidationFailed
      context "with a potentially missing cert store" do
        before{ stub_request(:get, mock_href).to_raise(OpenSSL::SSL::SSLError.new('unable to get local issuer certificate')) }
        it{ response.should raise_error(RHC::Rest::SSLConnectionFailed, /You may need to specify your system CA certificate file/) }
      end

      context "with a self-signed SSL certificate" do
        before do
          subject.should_receive(:self_signed?).and_return(true)
          stub_request(:get, mock_href).to_raise(OpenSSL::SSL::SSLError.new('Unverified SSL Certificate'))
        end
        it{ response.should raise_error(RHC::Rest::CertificateVerificationFailed, /The server is using a self-signed certificate/) }
      end

      context "with an unverified SSL certificate" do
        before{ stub_request(:get, mock_href).to_raise(OpenSSL::SSL::SSLError.new('self signed certificate')) }
        it{ response.should raise_error(RHC::Rest::CertificateVerificationFailed, /The server is using a self-signed certificate/) }
      end

      context "with an failed SSL certificate verification" do
        before{ stub_request(:get, mock_href).to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed')) }
        it{ response.should raise_error(RHC::Rest::CertificateVerificationFailed, /The server's certificate could not be verified.*test\.domain\.com/) }
      end

      context "with a socket error" do
        before{ stub_request(:get, mock_href).to_raise(SocketError) }
        it{ response.should raise_error(RHC::Rest::ConnectionException, /unable to connect to the server/i) }
      end

      context "with an SSL connection error" do
        before{ stub_request(:get, mock_href).to_raise(OpenSSL::SSL::SSLError) }
        it{ response.should raise_error(RHC::Rest::SSLConnectionFailed, /a secure connection could not be established/i) }
      end

      context "with an SSL certificate error" do
        before{ stub_request(:get, mock_href).to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed')) }
        it{ response.should raise_error(RHC::Rest::CertificateVerificationFailed, /the server's certificate could not be verified/i) }
      end

      context "with an SSL version exception" do
        before{ stub_request(:get, mock_href).to_raise(OpenSSL::SSL::SSLError.new('SSL_connect returned=1 errno=0 state=SSLv2/v3 read server hello A')) }
        it{ response.should raise_error(RHC::Rest::SSLVersionRejected, /connection attempt with an older ssl protocol/i) }
      end

      context "with a generic exception error" do
        before{ stub_request(:get, mock_href).to_raise(Exception.new('Generic Error')) }
        it{ response.should raise_error(RHC::Rest::ConnectionException, "An unexpected error occured: Generic Error") }
      end

      context "with a an unauthorized request" do
        before do
          return_data = {
            :body    => nil,
            :status  => 401,
            :headers => { 'Set-Cookie' => "rh_sso=test_ssh_cookie" }
          }
          stub_request(:get, mock_href).to_return(return_data)
        end
        it("raises not authenticated"){ response.should raise_error(RHC::Rest::UnAuthorizedException, 'Not authenticated') }
      end
    end

    # handle_error! function
    describe "#handle_error!" do
      let(:json){ nil }
      let(:body){ "<html><body>Something failed</body></html>" }
      let(:code){ nil }
      let(:client){ HTTPClient.new(:proxy => proxy) }
      let(:url){ "http://fake.url" }
      let(:proxy){ nil }
      def response
        mock(:status => code, :content => json ? RHC::Json.encode(json) : body)
      end
      let(:method) { lambda{ subject.send(:handle_error!, response, url, client) } }

      context "with a 400 response" do
        let(:code){ 400 }

        it{ method.should raise_error(RHC::Rest::ServerErrorException) }

        context "with a formatted JSON response" do
          let(:json){ {:messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a client error" do
            method.should raise_error(RHC::Rest::ClientErrorException, 'mock error message')
          end
        end
      end

      context "with a 401 response" do
        let(:code){ 401 }
        let(:json){ {} }
        it "raises an 'unauthorized exception' error" do
          method.should raise_error(RHC::Rest::UnAuthorizedException, 'Not authenticated')
        end
      end

      context "with a 403 response" do
        let(:code){ 403 }

        it "raises a request denied error" do
          method.should raise_error(RHC::Rest::RequestDeniedException)
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a 'request denied' error" do
            method.should raise_error(RHC::Rest::RequestDeniedException, 'mock error message')
          end
        end
      end

      context "with a 404 response" do
        let(:code){ 404 }

        it "raises a Not Found error" do
          method.should raise_error(RHC::Rest::ResourceNotFoundException)
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a 'resource not found' error" do
            method.should raise_error(RHC::Rest::ResourceNotFoundException, 'mock error message')
          end
        end
      end

      context "with a 409 response" do
        let(:code){ 409 }

        it "raises a generic server error" do
          method.should raise_error(RHC::Rest::ServerErrorException)
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a validation error" do
            method.should raise_error(RHC::Rest::ValidationException, 'mock error message')
          end
        end
        context "with multiple JSON messages" do
          let(:json){ { :messages => [{ :field => 'error', :text => 'mock error message 1' },
                                       { :field => 'error', :text => 'mock error message 2' }] } }
          it "raises a validation error with concatenated messages" do
            method.should raise_error(RHC::Rest::ValidationException, "The operation did not complete successfully, but the server returned additional information:\n* mock error message 1\n* mock error message 2")
          end
        end
        context "with multiple errors" do
          let(:json){ { :messages => [
                          { :severity => 'error', :field => 'error', :text => 'mock 1' },
                          { :severity => 'error', :text => 'mock 2' },
                        ] } }
          it "raises a validation error with concatenated messages" do
            method.should raise_error(RHC::Rest::ValidationException, "The server reported multiple errors:\n* mock 1\n* mock 2")
          end
        end
        context "with multiple messages and one error" do
          let(:json){ { :messages => [
                          { :field => 'error', :text => 'mock 1' },
                          { :text => 'mock 2' },
                          { :severity => 'error', :text => 'mock 3' },
                        ] } }
          it "raises a validation error with concatenated messages" do
            method.should raise_error(RHC::Rest::ValidationException, "mock 3")
          end
        end
        context "with an empty JSON response" do
          let(:json){ {} }
          it "raises a validation error" do
            method.should raise_error(RHC::Rest::ServerErrorException)
          end
        end
      end

      context "with a 422 response" do
        let(:code){ 422 }

        it "raises a generic server error" do
          method.should raise_error(RHC::Rest::ServerErrorException)
        end

        context "with a single JSON message" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a validation error" do
            method.should raise_error(RHC::Rest::ValidationException, 'mock error message')
          end
        end

        context "with an empty JSON response" do
          let(:json){ {} }
          it "raises a validation error" do
            method.should raise_error(RHC::Rest::ServerErrorException)
          end
        end

        context "with multiple JSON messages" do
          let(:json){ { :messages => [{ :field => 'error', :text => 'mock error message 1' },
                                       { :field => 'error', :text => 'mock error message 2' }] } }
          it "raises a validation error with concatenated messages" do
            method.should raise_error(RHC::Rest::ValidationException, "The operation did not complete successfully, but the server returned additional information:\n* mock error message 1\n* mock error message 2")
          end
        end
        context "with multiple errors" do
          let(:json){ { :messages => [
                          { :severity => 'error', :field => 'error', :text => 'mock 1' },
                          { :severity => 'error', :text => 'mock 2' },
                        ] } }
          it "raises a validation error with concatenated messages" do
            method.should raise_error(RHC::Rest::ValidationException, "The server reported multiple errors:\n* mock 1\n* mock 2")
          end
        end
        context "with multiple messages and one error" do
          let(:json){ { :messages => [
                          { :field => 'error', :text => 'mock 1' },
                          { :text => 'mock 2' },
                          { :severity => 'error', :text => 'mock 3' },
                        ] } }
          it "raises a validation error with concatenated messages" do
            method.should raise_error(RHC::Rest::ValidationException, "mock 3")
          end
        end
      end

      context "with a 500 response" do
        let(:code){ 500 }

        it "raises a generic server error" do
          method.should raise_error(RHC::Rest::ServerErrorException, /server did not respond correctly.*verify that you can access the OpenShift server/i)
        end

        context "when proxy is set" do
          let(:proxy) { 'http://foo.com' }
          it "raises a generic server error with the proxy URL" do
            method.should raise_error(RHC::Rest::ServerErrorException, /foo\.com/i)
          end
        end

        context "when request url is present" do
          let(:url){ 'foo.bar' }
          it "raises a generic server error with the request URL" do
            method.should raise_error(RHC::Rest::ServerErrorException, /foo\.bar/i)
          end
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a server error" do
            method.should raise_error(RHC::Rest::ServerErrorException, 'mock error message')
          end
        end
      end

      context "with a 503 response" do
        let(:code){ 503 }

        it "raises a 'service unavailable' error" do
          method.should raise_error(RHC::Rest::ServiceUnavailableException)
        end

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a 'service unavailable' error" do
            method.should raise_error(RHC::Rest::ServiceUnavailableException, 'mock error message')
          end
        end
      end

      context "with an unhandled response code" do
        let(:code){ 999 }

        it{ method.should raise_error(RHC::Rest::ServerErrorException) }

        context "with a formatted JSON response" do
          let(:json){ { :messages => [{ :severity => 'error', :text => 'mock error message' }] } }
          it "raises a resource access error" do
            method.should raise_error(RHC::Rest::ServerErrorException, 'mock error message')
          end
        end
      end
    end
  end
end
