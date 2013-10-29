require 'base64'
require 'spec_helper'
require 'stringio'
require 'rest_spec_helper'
require 'rhc/rest'

module RHC
  module Rest
    describe Client do

      after{ ENV['http_proxy'] = nil }
      after{ ENV['HTTP_PROXY'] = nil }

      it 'should set the proxy protocol if it is missing' do
        ENV['http_proxy'] = 'foo.bar.com:8081'
        expect{ RHC::Rest::Client.new.send(:httpclient_for, {}) }.to raise_error(ArgumentError)
      end

      it 'should not alter the proxy protocol if it is present' do
        ENV['http_proxy'] = 'http://foo.bar.com:8081'
        RHC::Rest::Client.new.send(:httpclient_for, {}).proxy.to_s.should == URI.parse(ENV['http_proxy']).to_s
      end

      it 'should not affect the proxy protocol if nil' do
        ENV['http_proxy'] = nil
        RHC::Rest::Client.new.send(:httpclient_for, {}).proxy.should be_nil
        ENV['http_proxy'].should be_nil
      end

      let(:endpoint){ mock_href }
      let(:username){ nil }
      let(:password){ nil }
      let(:use_debug){ false }
      let(:client) do
        respond_to?(:spec_versions) ?
          RHC::Rest::Client.new(endpoint, username, password, use_debug, spec_versions) :
          RHC::Rest::Client.new(endpoint, username, password, use_debug)
      end

      let(:client_links)   { mock_response_links(mock_client_links) }
      let(:domain_0_links) { mock_response_links(mock_domain_links('mock_domain_0')) }
      let(:domain_1_links) { mock_response_links(mock_domain_links('mock_domain_1')) }
      let(:app_0_links)    { mock_response_links(mock_app_links('mock_domain_0', 'mock_app')) }
      let(:user_links)     { mock_response_links(mock_user_links) }
      let(:key_links)      { mock_response_links(mock_key_links) }
      let(:api_links)      { client_links }

      context "#new" do
        before do
          stub_api_request(:get, '').
            to_return({ :body   => { :data => client_links, :supported_api_versions => [1.0, 1.1] }.to_json,
                        :status => 200
                      })
          stub_api_request(:get, 'api_error').
            to_raise(HTTPClient::BadResponseError.new('API Error'))
          stub_api_request(:get, 'other_error').
            to_raise(StandardError.new('Other Error'))
        end

        it "returns a client object from the required arguments" do
          credentials = Base64.strict_encode64(mock_user + ":" + mock_pass)
          client.api.send(:links).should == client_links
        end
        context "against an endpoint that won't connect" do
          let(:endpoint){ mock_href('api_error') }
          it "raises an error message" do
            expect{ client.api }.to raise_error
          end
        end
        context "against an endpoint that has a generic error" do
          let(:endpoint){ mock_href('other_error') }
          it "raises a generic error for any other error condition" do
            expect{ client.api }.to raise_error(RHC::Rest::ConnectionException, "An unexpected error occured: Other Error")
          end
        end
      end

      describe "#new" do
        context "when server supports API versions [1.0, 1.1]" do
          before :each do
            stub_api_request(:get, '').
              with(:headers => {'Accept' => 'application/json'}).
              to_return({ :status => 200, :body => { :data => client_links, :version => '1.0', :supported_api_versions => [1.0, 1.1] }.to_json })
            stub_api_request(:get, '').
              with(:headers => {'Accept' => 'application/json;version=1.0'}).
              to_return({ :status => 200, :body => { :data => client_links, :version => '1.0', :supported_api_versions => [1.0, 1.1] }.to_json })
            stub_api_request(:get, '').
              with(:headers => {'Accept' => 'application/json;version=1.1'}).
              to_return({ :status => 200, :body => { :data => client_links, :version => '1.1', :supported_api_versions => [1.0, 1.1] }.to_json })
            stub_api_request(:get, '').
              with(:headers => {'Accept' => /application\/json;version=(1.2|1.3)/}).
              to_raise(StandardError.new('Bad Version'))
            stub_api_request(:get, 'api_error').
              to_raise(HTTPClient::BadResponseError.new('API Error'))
            stub_api_request(:get, 'other_error').
              to_raise(StandardError.new('Other Error'))
          end

          context "when client is instantiated with [1.0, 1.1] as the preferred API versions" do
            let(:spec_versions){ [1.0, 1.1] }
            it "settles on 1.1 as the API version" do
              client.api.api_version_negotiated.should == 1.1
            end
          end

          context "when client is instantiated with [1.1, 1.0] as the preferred API versions" do
            let(:spec_versions){ [1.1, 1.0] }
            it "settles on 1.0 as the API version" do
              client.api.api_version_negotiated.should == 1.0
            end
          end

          context "when client is instantiated with [1.2, 1.3] as the preferred API versions" do
            let(:spec_versions){ [1.2, 1.3] }
            it "fails to negotiate an agreeable API version" do
              client.api.api_version_negotiated.should be_nil
            end
          end

          context "when client is instantiated with [1.1, 1.0, 1.3] as the preferred API versions" do
            let(:spec_versions){ [1.1, 1.0, 1.3] }
            it "settles on 1.0 as the API version" do
              client.api.api_version_negotiated.should == 1.0
            end
          end
        end
      end

      context "with an instantiated client " do
        before do
          stub_api_request(:get, '').
            to_return({ :body   => {
                          :data => api_links,
                          :supported_api_versions => [1.0, 1.1]
                        }.to_json,
                        :status => 200
                      })
        end

        context "#add_domain" do
          before do
            stub_api_request(:any, api_links['ADD_DOMAIN']['relative']).
              to_return({ :body   => {
                            :type => 'domain',
                            :supported_api_versions => [1.0, 1.1],
                            :data => {
                              :id    => 'mock_domain',
                              :links => mock_response_links(mock_domain_links('mock_domain')),
                            }
                          }.to_json,
                          :status => 200
                        })
          end
          it "returns a domain object" do
            domain = client.add_domain('mock_domain')
            domain.class.should == RHC::Rest::Domain
            domain.name.should == 'mock_domain'
            domain.send(:links).should ==
              mock_response_links(mock_domain_links('mock_domain'))
          end
        end

        context "#update_members" do
          subject{ RHC::Rest::Application.new }
          it "raises when the update link is disabled" do
            subject.should_receive(:supports_members?).and_return(true)
            expect{ subject.update_members([]) }.to raise_error(RHC::ChangeMembersOnResourceNotSupported)
          end
        end

        context "#domains" do
          before(:each) do
            stub_api_request(:any, api_links['LIST_DOMAINS']['relative']).
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
            domains = client.domains
            domains.length.should equal(2)
            (0..1).each do |idx|
              domains[idx].class.should == RHC::Rest::Domain
              domains[idx].name.should    == "mock_domain_#{idx}"
              domains[idx].send(:links).should ==
                mock_response_links(mock_domain_links("mock_domain_#{idx}"))
            end
          end
          it "returns an empty list when no domains exist" do
            # Disregard the first response; this is for the previous expectiation.
            domains = client.domains
            client.instance_variable_set(:@domains, nil)
            domains = client.domains
            domains.length.should equal(0)
          end
        end

        context "#find_domain" do
          context "when server does not support SHOW_DOMAIN" do
            before do
              stub_api_request(:any, api_links['LIST_DOMAINS']['relative']).
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
              expect { match = client.find_domain('mock_domain_0') }.to_not raise_error
              match.name.should == 'mock_domain_0'
              match.class.should == RHC::Rest::Domain
            end
            it "returns a domain object for matching case-insensitive domain IDs" do
              match = nil
              expect { match = client.find_domain('MOCK_DOMAIN_0') }.to_not raise_error
              match.name.should == 'mock_domain_0'
              match.class.should == RHC::Rest::Domain
            end
            it "raise an error when no matching domain IDs can be found" do
              expect { client.find_domain('mock_domain_2') }.to raise_error(RHC::Rest::DomainNotFoundException)
            end
          end

          context "when server supports SHOW_DOMAIN" do
            let(:api_links){ client_links.merge!(mock_response_links([['SHOW_DOMAIN', 'domains/:name', 'get']])) }
            before do
              stub_api_request(:any, api_links['SHOW_DOMAIN']['relative'].gsub(/:name/, 'mock_domain_0')).
                to_return({ :body   => {
                              :type => 'domain',
                              :data =>
                              { :id    => 'mock_domain_0',
                                 :links => mock_response_links(mock_domain_links('mock_domain_0')),
                               }
                            }.to_json,
                            :status => 200
                          })
              stub_api_request(:any, api_links['SHOW_DOMAIN']['relative'].gsub(/:name/, 'mock_domain_%^&')).
                to_return({ :body   => {
                              :type => 'domain',
                              :data =>
                              { :id    => 'mock_domain_%^&',
                                 :links => mock_response_links(mock_domain_links('mock_domain_0')),
                               }
                            }.to_json,
                            :status => 200
                          })
              stub_api_request(:any, api_links['SHOW_DOMAIN']['relative'].gsub(/:name/, 'mock_domain_2')).
                to_return({ :body => {:messages => [{:exit_code => 127}, {:severity => 'warning', :text => 'A warning'}]}.to_json,
                            :status => 404
                          })
            end
            it "returns a domain object for matching domain IDs" do
              match = nil
              expect { match = client.find_domain('mock_domain_0') }.to_not raise_error
              match.name.should == 'mock_domain_0'
              match.class.should == RHC::Rest::Domain
            end
            it "encodes special characters" do
              match = nil
              expect { match = client.find_domain('mock_domain_%^&') }.to_not raise_error
              match.name.should == 'mock_domain_%^&'
              match.class.should == RHC::Rest::Domain
            end
            it "raise an error when no matching domain IDs can be found" do
              expect{ client.find_domain('mock_domain_2') }.to raise_error(RHC::Rest::DomainNotFoundException)
            end
            it "prints a warning when an error is returned" do
              client.should_receive(:warn).with('A warning')
              expect{ client.find_domain('mock_domain_2') }.to raise_error(RHC::Rest::DomainNotFoundException)
            end
          end
        end

        context "when server supports LIST_DOMAINS_BY_OWNER" do
          let(:api_links){ client_links.merge!(mock_response_links([['LIST_DOMAINS_BY_OWNER', 'domains', 'get']])) }
          before do
            stub_api_request(:any, "#{api_links['LIST_DOMAINS_BY_OWNER']['relative']}?owner=@self").
              to_return({ :body   => {
                            :type => 'domains',
                            :data => [{
                              :id    => 'mock_domain_0',
                              :links => mock_response_links(mock_domain_links('mock_domain_0')),
                            }]
                          }.to_json,
                          :status => 200
                        })
          end
          it "returns owned domains when called" do
            match = nil
            expect { match = client.owned_domains }.to_not raise_error
            match.length.should == 1
            match.first.name.should == 'mock_domain_0'
            match.first.class.should == RHC::Rest::Domain
          end
        end

        context "find_application" do
          let(:mock_domain){ 'mock_domain_0' }
          let(:mock_app){ 'mock_app' }
          let(:missing){ 'no_match' }
          before(:each) do
            stub_one_application(mock_domain, mock_app)
            stub_one_application(mock_domain, missing, {
              :type => nil,
              :data => nil,
              :messages => [{
                :exit_code => 101,
                :field => nil,
                :severity => 'error',
                :text => "Application #{missing} not found"
              }],
              :status => 'not_found'
            }, 404)
            stub_one_application(missing, mock_app, {
              :type => nil,
              :data => nil,
              :messages => [{
                :exit_code => 127,
                :field => nil,
                :severity => 'error',
                :text => "Domain #{missing} not found"
              }],
              :status => 'not_found'
            }, 404)
          end
          it "returns application object for nested application IDs" do
              match = client.find_application(mock_domain, mock_app)
              match.class.should     == RHC::Rest::Application
              match.name.should      == mock_app
              match.domain_id.should == mock_domain
              match.send(:links).should     ==
                mock_response_links(mock_app_links(mock_domain, mock_app))
          end
          it "Raises an exception when no matching applications can be found" do
            expect { client.find_application(mock_domain, missing) }.to raise_error(RHC::Rest::ApplicationNotFoundException)
          end
          it "Raises an exception when no matching domain can be found" do
            expect { client.find_application(missing, mock_app) }.to raise_error(RHC::Rest::DomainNotFoundException)
          end
        end

        context "#find_application_by_id" do
          context "when server does not support SHOW_APPLICATION" do
            let(:server){ mock_uri }
            let(:endpoint){ "https://#{server}/broker/rest/api"}
            before do
              stub_api
              stub_one_domain('test')
              stub_one_application('test', 'app1')
            end
            it "returns an app object for matching IDs" do
              match = nil
              expect { match = client.find_application_by_id(1) }.to_not raise_error
              match.id.should == 1
              match.class.should == RHC::Rest::Application
            end
            it "raise an error when no matching app IDs can be found" do
              expect { client.find_application_by_id('2') }.to raise_error(RHC::Rest::ApplicationNotFoundException)
            end
          end

          context "when server supports SHOW_APPLICATION" do
            let(:api_links){ mock_response_links([['SHOW_APPLICATION', 'application/:id', 'get']]) }
            before do
              stub_api_request(:any, api_links['SHOW_APPLICATION']['relative'].gsub(/:id/, 'app_0')).
                to_return({ :body   => {
                              :type => 'application',
                              :data =>
                              { :id    => 'app_0',
                                :links => mock_response_links(mock_app_links('app_0')),
                               }
                            }.to_json,
                            :status => 200
                          })
              stub_api_request(:any, api_links['SHOW_APPLICATION']['relative'].gsub(/:id/, 'app_1')).
                to_return({ :body => {:messages => [{:exit_code => 101}]}.to_json,
                            :status => 404
                          })
            end
            it "returns an app object for matching IDs" do
              match = nil
              expect { match = client.find_application_by_id('app_0') }.to_not raise_error
              match.id.should == 'app_0'
              match.class.should == RHC::Rest::Application
            end
            it "raise an error when no matching IDs can be found" do
              expect { client.find_application_by_id('app_1') }.to raise_error(RHC::Rest::ApplicationNotFoundException)
            end
            it "should fetch application ids" do
              client.api
              client.should_receive(:request).with(:url => "#{api_links['SHOW_APPLICATION']['href'].gsub(/:id/, 'app_2')}", :method => "GET", :payload => {}).and_return(1)
              client.find_application_by_id('app_2').should == 1
            end
            it "should fetch application gear groups" do
              client.api
              client.should_receive(:request).with(:url => "#{api_links['SHOW_APPLICATION']['href'].gsub(/:id/, 'app_2')}/gear_groups", :method => "GET", :payload => {}).and_return(1)
              client.find_application_by_id_gear_groups('app_2').should == 1
            end
          end
        end

        describe RHC::Rest::Cartridge do
          subject do
            RHC::Rest::Cartridge.new({
              :name => 'foo',
              :links => mock_response_links([
                ['GET', 'broker/rest/cartridge', 'get']
              ])}, client)
          end
          context "when several messages are present" do
            before do
              stub_api_request(:get, 'broker/rest/cartridge', true).
                with(:query => {:include => 'status_messages'}).
                to_return(:body => {
                  :type => 'cartridge',
                  :data => {
                    :status_messages => [{:message => 'Test'}]
                  }
                }.to_json)
            end
            its(:status){ should == [{'message' => 'Test'}] }
          end
        end

        context "#cartridges" do
          before(:each) do
            stub_api_request(:any, api_links['LIST_CARTRIDGES']['relative']).
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
            carts = client.cartridges
            carts.length.should equal(2)
            (0..1).each do |idx|
              carts[idx].class.should == RHC::Rest::Cartridge
              carts[idx].name.should  == "mock_cart_#{idx}"
              carts[idx].type.should  == "mock_cart_#{idx}_type"
              carts[idx].send(:links).should ==
                mock_response_links(mock_cart_links("mock_cart_#{idx}"))
            end
          end
          it "caches cartridges on the client" do
            # Disregard the first response; this is for the previous expectiation.
            old = client.cartridges.length
            client.cartridges.length.should equal(old)
            client.instance_variable_set(:@cartridges, nil)
            client.cartridges.length.should equal(0)
          end
        end

        context "#find_cartridges" do
          before(:each) do
            stub_api_request(:any, api_links['LIST_CARTRIDGES']['relative']).
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
            matches = client.find_cartridges('mock_cart_0')
            matches.length.should equal(1)
            matches[0].class.should == RHC::Rest::Cartridge
            matches[0].name.should  == 'mock_cart_0'
            matches[0].type.should  == 'mock_cart_0_type'
            matches[0].send(:links).should ==
              mock_response_links(mock_cart_links('mock_cart_0'))
          end
          it "returns an empty list when no matching cartridges can be found" do
            matches = client.find_cartridges('no_match')
            matches.length.should equal(0)
          end
          it "returns multiple cartridge matches" do
            matches = client.find_cartridges :regex => "mock_cart_[0-9]"
            matches.length.should equal(2)
          end
        end

        context "#user" do
          before(:each) do
            stub_api_request(:any, api_links['GET_USER']['relative']).
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
            user = client.user
            user.class.should  == RHC::Rest::User
            user.login.should  == mock_user
            user.send(:links).should  == mock_response_links(mock_user_links)
          end
        end

        context "#find_key" do
          before(:each) do
            stub_api_request(:any, api_links['GET_USER']['relative']).
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
            expect { key = client.find_key('mock_key_0') }.to_not raise_error

            key.class.should   == RHC::Rest::Key
            key.name.should    == 'mock_key_0'
            key.type.should    == 'mock_key_0_type'
            key.content.should == '123456789:0'
            key.send(:links).should   ==
              mock_response_links(mock_key_links('mock_key_0'))
          end
          it "raise an error when no matching keys can be found" do
            expect { client.find_key('no_match') }.to raise_error(RHC::KeyNotFoundException)
          end
        end

        context "#delete_key" do
          before(:each) do
            stub_api_request(:any, api_links['GET_USER']['relative']).
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
          end

          it "should delete keys" do
            expect { client.delete_key('mock_key_0') }.to be_true
          end

          it 'raises an error if nonexistent key is requested' do
            expect { client.find_key('no_match') }.to raise_error(RHC::KeyNotFoundException)
          end
        end
      end

      context "when server supports API versions 1.0 and 1.1" do
        before :each do
          stub_api_request(:get, '').
            to_return({ :body   => {
                          :data => api_links,
                          :supported_api_versions => [1.0, 1.1]
                        }.to_json,
                        :status => 200
                      })
        end

        context "when client supports API version 1.1" do
          let(:spec_versions){ [1.1] }

          describe "#api_version_negotiated" do
            it "returns 1.1" do
              client.api.api_version_negotiated.to_s.should == '1.1'
            end
          end
        end

        context "when client supports only API version 1.2" do
          let(:spec_versions){ [1.2] }

          describe "#api_version_negotiated" do
            it 'returns nil' do
              client.api.api_version_negotiated.should be_nil
            end
          end
        end

        context "when client supports only API version 0.9" do
          describe "#new" do
            let(:spec_versions){ [0.9] }
            it "warns user that it is outdated" do
              capture do
                client.api
                @output.rewind
                @output.read.should =~ /client version may be outdated/
              end
            end
          end
        end
      end

      describe "#supports_sessions?" do
        before{ subject.should_receive(:api).at_least(2).times.and_return(double) }
        context "with ADD_AUTHORIZATION link" do
          before{ subject.api.should_receive(:supports?).with('ADD_AUTHORIZATION').and_return(true) }
          its(:supports_sessions?){ should be_true }
        end
        context "without ADD_AUTHORIZATION link" do
          before{ subject.api.should_receive(:supports?).with('ADD_AUTHORIZATION').and_return(false) }
          its(:supports_sessions?){ should be_false }
        end
      end

      describe "#authorizations" do
        before do
          stub_api_request(:get, '').to_return({:body => {
              :data => mock_response_links(mock_api_with_authorizations),
              :supported_api_versions => [1.0, 1.1]
            }.to_json,
            :status => 200
          })
          stub_authorizations
        end
        it{ client.authorizations.first.token.should == 'a_token_value' }
        it{ client.authorizations.first.note.should == 'an_authorization' }
        it{ client.authorizations.first.expires_in_seconds.should == 60 }
      end
    end
  end
end

module RHC
  module Rest
    describe HTTPClient do
    end

    describe WWWAuth::DeferredCredential do
      subject{ described_class.new(nil, nil) }
      its(:user){ should be_nil }
      its(:passwd){ should be_nil }

      context "with a username and password" do
        subject{ described_class.new(username, password) }
        let(:username){ 'a_user' }
        let(:password){ 'a_password' }

        its(:user){ should == username }
        its(:passwd){ should == password }
        its(:to_str){ should == ["#{username}:#{password}"].pack('m').tr("\n", '') }
      end

      context "with a deferred username and password" do
        subject{ described_class.new(username, password) }
        let(:username){ lambda{ 'a_user' } }
        let(:password){ lambda{ 'a_password' } }

        its(:user){ should == username.call }
        its(:passwd){ should == password.call }
        its(:to_str){ should == ["#{username.call}:#{password.call}"].pack('m').tr("\n", '') }
      end
    end
  end
end
