require 'base64'
require 'spec_helper'
require 'stringio'
require 'rest_spec_helper'
require 'rhc/rest/client'

Spec::Runner.configure do |configuration|
  include(RestSpecHelper)
end

# This object is used in a few cases where we need to inspect
# the logged output.
class MockClient < RHC::Rest::Client
  def logger
    Logger.new((@output = StringIO.new))
  end
  def use_debug
    @debug = true
  end
  def logged
    @output.string
  end
end

module RHC
  module Rest
    describe Client do
      let(:client_links)   { mock_response_links(mock_client_links) }
      let(:domain_0_links) { mock_response_links(mock_domain_links('mock_domain_0')) }
      let(:domain_1_links) { mock_response_links(mock_domain_links('mock_domain_1')) }
      let(:app_0_links)    { mock_response_links(mock_app_links('mock_domain_0', 'mock_app')) }
      let(:user_links)     { mock_response_links(mock_user_links) }
      let(:key_links)      { mock_response_links(mock_key_links) }

      context "#new" do
        before do
          stub_api_request(:get, '').
            to_return({ :body   => { :data => client_links }.to_json,
                        :status => 200
                      })
          stub_api_request(:get, 'api_error').
            to_raise(RestClient::ExceptionWithResponse.new('API Error'))
          stub_api_request(:get, 'other_error').
            to_raise(Exception.new('Other Error'))
        end

        it "returns a client object from the required arguments" do
          credentials = Base64.strict_encode64(mock_user + ":" + mock_pass)
          client      = RHC::Rest::Client.new(mock_href, mock_user, mock_pass)
          @@headers['Authorization'].should == "Basic #{credentials}"
          client.send(:links).should == client_links
        end
        it "does not add newlines to username and password > 60 characters" do
          username = "a" * 45
          password = "p" * 45
          client   = RHC::Rest::Client.new(mock_href, mock_user, mock_pass)
          @@headers['Authorization'].should_not match("\n")
        end
        it "raises an error message if the API cannot be connected" do
          expect { MockClient.new(mock_href('api_error'), mock_user, mock_pass) }.should raise_error
        end
        it "raises a generic error for any other error condition" do
          lambda{ RHC::Rest::Client.new(mock_href('other_error'), mock_user, mock_pass) }.
            should raise_error("Failed to access resource: Other Error")
        end
      end

      context "with an instantiated client " do
        before(:each) do
          stub_api_request(:get, '').
            to_return({ :body   => { :data => client_links }.to_json,
                        :status => 200
                      })
          @client = RHC::Rest::Client.new(mock_href, mock_user, mock_pass)
        end

        context "#add_domain" do
          before do
            stub_api_request(:any, client_links['ADD_DOMAIN']['relative']).
              to_return({ :body   => {
                            :type => 'domain',
                            :data => {
                              :id    => 'mock_domain',
                              :links => mock_response_links(mock_domain_links('mock_domain')),
                            }
                          }.to_json,
                          :status => 200
                        })
          end
          it "returns a domain object" do
            domain = @client.add_domain('mock_domain')
            domain.class.should == RHC::Rest::Domain
            domain.id.should == 'mock_domain'
            domain.send(:links).should ==
              mock_response_links(mock_domain_links('mock_domain'))
          end
        end

        context "#domains" do
          before(:each) do
            stub_api_request(:any, client_links['LIST_DOMAINS']['relative']).
              to_return({ :body   => {
                            :type => 'domains',
                            :data =>
                            [{ :id    => 'mock_domain_0',
                               :links => mock_response_links(mock_domain_links('mock_domain_0')),
                             },
                             { :id    => 'mock_domain_1',
                               :links => mock_response_links(mock_domain_links('mock_domain_1')),
                             }]
                          }.to_json,
                          :status => 200
                        }).
              to_return({ :body   => {
                            :type => 'domains',
                            :data => []
                          }.to_json,
                          :status => 200
                        })
          end
          it "returns a list of existing domains" do
            domains = @client.domains
            domains.length.should equal(2)
            (0..1).each do |idx|
              domains[idx].class.should                          == RHC::Rest::Domain
              domains[idx].id.should    == "mock_domain_#{idx}"
              domains[idx].send(:links).should ==
                mock_response_links(mock_domain_links("mock_domain_#{idx}"))
            end
          end
          it "returns an empty list when no domains exist" do
            # Disregard the first response; this is for the previous expectiation.
            domains = @client.domains
            domains = @client.domains
            domains.length.should equal(0)
          end
        end

        context "#find_domain" do
          before(:each) do
            stub_api_request(:any, client_links['LIST_DOMAINS']['relative']).
              to_return({ :body   => {
                            :type => 'domains',
                            :data =>
                            [{ :id    => 'mock_domain_0',
                               :links => mock_response_links(mock_domain_links('mock_domain_0')),
                             },
                             { :id    => 'mock_domain_1',
                               :links => mock_response_links(mock_domain_links('mock_domain_1')),
                             }]
                          }.to_json,
                          :status => 200
                        })
          end
          it "returns a domain object for matching domain IDs" do
            match = nil
            expect { match = @client.find_domain('mock_domain_0') }.should_not raise_error

            match.id.should == 'mock_domain_0'
            match.class.should == RHC::Rest::Domain
          end
          it "raise an error when no matching domain IDs can be found" do
            expect { @client.find_domain('mock_domain_2') }.should raise_error(RHC::DomainNotFoundException)
          end
        end

        context "#find_application" do
          before(:each) do
            stub_api_request(:any, client_links['LIST_DOMAINS']['relative']).
              to_return({ :body   => {
                            :type => 'domains',
                            :data =>
                            [{ :id    => 'mock_domain_0',
                               :links => mock_response_links(mock_domain_links('mock_domain_0')),
                             },
                             { :id    => 'mock_domain_1',
                               :links => mock_response_links(mock_domain_links('mock_domain_1')),
                             }]
                          }.to_json,
                          :status => 200
                        })
            stub_api_request(:any, domain_0_links['LIST_APPLICATIONS']['relative']).
              to_return({ :body   => {
                            :type => 'applications',
                            :data =>
                            [{ :domain_id       => 'mock_domain_0',
                               :name            => 'mock_app',
                               :creation_time   => Time.new.to_s,
                               :uuid            => 1234,
                               :aliases         => ['alias_1', 'alias_2'],
                               :server_identity => 'mock_server_identity',
                               :links           => mock_response_links(mock_app_links('mock_domain_0','mock_app')),
                             }]
                          }.to_json,
                          :status => 200
                        })
            stub_api_request(:any, domain_1_links['LIST_APPLICATIONS']['relative']).
              to_return({ :body   => {
                            :type => 'applications',
                            :data =>
                            [{ :domain_id       => 'mock_domain_1',
                               :name            => 'mock_app',
                               :creation_time   => Time.new.to_s,
                               :uuid            => 1234,
                               :aliases         => ['alias_1', 'alias_2'],
                               :server_identity => 'mock_server_identity',
                               :links           => mock_response_links(mock_app_links('mock_domain_1','mock_app')),
                             }]
                          }.to_json,
                          :status => 200
                        })
          end
          it "returns application objects for matching application IDs" do
            domain = @client.domains[0]
            domain.applications.each do |app|
              match = domain.find_application(app.name)
              match.class.should                              == RHC::Rest::Application
              match.name.should      == 'mock_app'
              match.domain_id.should == "#{domain.id}"
              match.send(:links).should     ==
                mock_response_links(mock_app_links("#{domain.id}",'mock_app'))
            end
          end
          it "Raises an excpetion when no matching applications can be found" do
            expect { @client.domains[0].find_application('no_match') }.should raise_error(RHC::ApplicationNotFoundException)
          end
        end

        context "#cartridges" do
          before(:each) do
            stub_api_request(:any, client_links['LIST_CARTRIDGES']['relative']).
              to_return({ :body   => {
                            :type => 'cartridges',
                            :data =>
                            [{ :name  => 'mock_cart_0',
                               :type  => 'mock_cart_0_type',
                               :links => mock_response_links(mock_cart_links('mock_cart_0')),
                             },
                             { :name  => 'mock_cart_1',
                               :type  => 'mock_cart_1_type',
                               :links => mock_response_links(mock_cart_links('mock_cart_1')),
                             }]
                          }.to_json,
                          :status => 200
                        }).
              to_return({ :body   => {
                            :type => 'cartridges',
                            :data => []
                          }.to_json,
                          :status => 200
                        })
          end
          it "returns a list of existing cartridges" do 
            carts = @client.cartridges
            carts.length.should equal(2)
            (0..1).each do |idx|
              carts[idx].class.should                          == RHC::Rest::Cartridge
              carts[idx].name.should  == "mock_cart_#{idx}"
              carts[idx].type.should  == "mock_cart_#{idx}_type"
              carts[idx].send(:links).should ==
                mock_response_links(mock_cart_links("mock_cart_#{idx}"))
            end
          end
          it "returns an empty list when no cartridges exist" do
            # Disregard the first response; this is for the previous expectiation.
            carts = @client.cartridges
            carts = @client.cartridges
            carts.length.should equal(0)
          end
        end

        context "#find_cartridges" do
          before(:each) do
            stub_api_request(:any, client_links['LIST_CARTRIDGES']['relative']).
              to_return({ :body   => {
                            :type => 'cartridges',
                            :data =>
                            [{ :name  => 'mock_cart_0',
                               :type  => 'mock_cart_0_type',
                               :links => mock_response_links(mock_cart_links('mock_cart_0')),
                             },
                             { :name  => 'mock_cart_1',
                               :type  => 'mock_cart_1_type',
                               :links => mock_response_links(mock_cart_links('mock_cart_1')),
                             },
                             { :name  => 'mock_nomatch_cart_0',
                               :type  => 'mock_nomatch_cart_0_type',
                               :links => mock_response_links(mock_cart_links('mock_nomatch_cart_0')),
                             }
                            ]
                          }.to_json,
                          :status => 200
                        })
          end
          it "returns a list of cartridge objects for matching cartridges" do
            matches = @client.find_cartridges('mock_cart_0')
            matches.length.should equal(1)
            matches[0].class.should                          == RHC::Rest::Cartridge
            matches[0].name.should  == 'mock_cart_0'
            matches[0].type.should  == 'mock_cart_0_type'
            matches[0].send(:links).should ==
              mock_response_links(mock_cart_links('mock_cart_0'))
          end
          it "returns an empty list when no matching cartridges can be found" do
            matches = @client.find_cartridges('no_match')
            matches.length.should equal(0)
          end
          it "returns multiple cartridge matches" do
            matches = @client.find_cartridges :regex => "mock_cart_[0-9]"
            matches.length.should equal(2)
          end
        end

        context "#user" do
          before(:each) do
            stub_api_request(:any, client_links['GET_USER']['relative']).
              to_return({ :body   => {
                            :type => 'user',
                            :data =>
                            { :login => mock_user,
                              :links => mock_response_links(mock_user_links)
                            }
                          }.to_json,
                          :status => 200
                        })
          end
          it "returns the user object associated with this client connection" do
            user = @client.user
            user.class.should                           == RHC::Rest::User
            user.login.should  == mock_user
            user.send(:links).should  == mock_response_links(mock_user_links)
          end
        end

        context "#find_key" do
          before(:each) do
            stub_api_request(:any, client_links['GET_USER']['relative']).
              to_return({ :body   => {
                            :type => 'user',
                            :data =>
                            { :login => mock_user,
                              :links => mock_response_links(mock_user_links)
                            }
                          }.to_json,
                          :status => 200
                        })
            stub_api_request(:any, user_links['LIST_KEYS']['relative']).
              to_return({ :body   => {
                            :type => 'keys',
                            :data =>
                            [{ :name    => 'mock_key_0',
                               :type    => 'mock_key_0_type',
                               :content => '123456789:0',
                               :links   => mock_response_links(mock_key_links('mock_key_0'))
                             },
                             { :name    => 'mock_key_1',
                               :type    => 'mock_key_1_type',
                               :content => '123456789:1',
                               :links   => mock_response_links(mock_key_links('mock_key_1'))
                             }]
                          }.to_json,
                          :status => 200
                        })
          end
          it "returns a list of key objects for matching keys" do
            key = nil
            expect { key = @client.find_key('mock_key_0') }.should_not raise_error

            key.class.should                            == RHC::Rest::Key
            key.name.should    == 'mock_key_0'
            key.type.should    == 'mock_key_0_type'
            key.content.should == '123456789:0'
            key.send(:links).should   ==
              mock_response_links(mock_key_links('mock_key_0'))
          end
          it "raise an error when no matching keys can be found" do
            expect { @client.find_key('no_match') }.should raise_error(RHC::KeyNotFoundException)
          end
        end

        shared_examples_for "a logout method" do
          before(:each) do
            stub_api_request(:get, '').
              to_return({ :body   => { :data => client_links }.to_json,
                          :status => 200
                        })
            @client = MockClient.new(mock_href, mock_user, mock_pass)
          end
          context "debug mode is on" do
            it "writes a message to the logger" do
              @client.use_debug
              @client.logger # starts our mock logger
              eval '@client.' + logout_method.to_s
              @client.logged.should =~ /Logout\/Close client$/
            end
          end
          context "debug mode is off" do
            it "does nothing" do
              @client = MockClient.new(mock_href, mock_user, mock_pass)
              @client.logger # starts our mock logger
              eval '@client.' + logout_method.to_s
              @client.logged.should == ''
            end
          end
        end

        context "#delete_key" do
          before(:each) do
            stub_api_request(:any, client_links['GET_USER']['relative']).
              to_return({ :body   => {
                            :type => 'user',
                            :data =>
                            { :login => mock_user,
                              :links => mock_response_links(mock_user_links)
                            }
                          }.to_json,
                          :status => 200
                        })
            stub_api_request(:any, user_links['LIST_KEYS']['relative']).
              to_return({ :body   => {
                            :type => 'keys',
                            :data =>
                            [{ :name    => 'mock_key_0',
                               :type    => 'mock_key_0_type',
                               :content => '123456789:0',
                               :links   => mock_response_links(mock_key_links('mock_key_0'))
                             },
                             { :name    => 'mock_key_1',
                               :type    => 'mock_key_1_type',
                               :content => '123456789:1',
                               :links   => mock_response_links(mock_key_links('mock_key_1'))
                             }]
                          }.to_json,
                          :status => 200
                        })

            stub_api_request(:post, key_links['DELETE']['relative']).
              to_return({ :body   => {}.to_json,
                          :status => 200
                        })

            @client = MockClient.new(mock_href, mock_user, mock_pass)
          end
          
          it "should delete keys" do
            expect { @client.delete_key('mock_key_0') }.should be_true
          end
          
          it 'raises an error if nonexistent key is requested' do
            expect { @client.find_key('no_match') }.
              should raise_error(RHC::KeyNotFoundException)
          end
        end
        
        context "#logout" do
          let(:logout_method) { :logout }
          it_should_behave_like "a logout method"
        end

        context "#close" do
          let(:logout_method) { :close }
          it_should_behave_like "a logout method"
        end
      end
    end
  end
end
