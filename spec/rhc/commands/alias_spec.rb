require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/alias'
require 'rhc/config'
describe RHC::Commands::Alias do
  let(:client_links)   { mock_response_links(mock_client_links) }
  let(:domain_0_links) { mock_response_links(mock_domain_links('mock_domain_0')) }
  let(:domain_1_links) { mock_response_links(mock_domain_links('mock_domain_1')) }
  let(:app_0_links)    { mock_response_links(mock_app_links('mock_domain_0', 'mock_app_0')) }
  before(:each) do
    RHC::Config.set_defaults
    @rc = MockRestClient.new
    @rc.add_domain("mock_domain_0").add_application("mock_app_0", "ruby-1.8.7")
    stub_api_request(:any, client_links['LIST_DOMAINS']['relative']).with(:headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate'}).
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
    stub_api_request(:any, domain_0_links['LIST_APPLICATIONS']['relative']).with(:headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate'}).
            to_return({ :body   => {
                    :type => 'applications',
                    :data =>
                    [{ :domain_id       => 'mock_domain_0',
                       :name            => 'mock_app_0',
                       :creation_time   => Time.new.to_s,
                       :uuid            => 1234,
                       :aliases         => ['alias_1', 'alias_2'],
                       :server_identity => 'mock_server_identity',
                       :links           => mock_response_links(mock_app_links('mock_domain_0','mock_app_0')),
                     }]
                  }.to_json,
                  :status => 200
                })
    stub_api_request(:any, app_0_links['ADD_ALIAS']['relative']).with(:body => {:event => 'add-alias', :alias => 'www.foo.bar'}, :headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'33', 'Content-Type'=>'application/x-www-form-urlencoded'}).
            to_return({ :body   => {
                          :type => 'application',
                          :data =>
                          { :domain_id       => 'mock_domain_1',
                             :name            => 'mock_app_0',
                             :creation_time   => Time.new.to_s,
                             :uuid            => 1234,
                             :aliases         => ['alias_1', 'alias_2'],
                             :server_identity => 'mock_server_identity',
                             :links           => mock_response_links(mock_app_links('mock_domain_1','mock_app_0')),
                           },
                          :messages => [{:text => "RESULT:\nApplication event 'add-alias' successful"}]
                        }.to_json,
                        :status => 200
                      })
stub_api_request(:any, app_0_links['REMOVE_ALIAS']['relative']).with(:body => {:event => 'remove-alias', :alias => 'www.foo.bar'}, :headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'36', 'Content-Type'=>'application/x-www-form-urlencoded'}).
            to_return({ :body   => {
                          :type => 'application',
                          :data =>
                          { :domain_id       => 'mock_domain_1',
                             :name            => 'mock_app_0',
                             :creation_time   => Time.new.to_s,
                             :uuid            => 1234,
                             :aliases         => ['alias_1', 'alias_2'],
                             :server_identity => 'mock_server_identity',
                             :links           => mock_response_links(mock_app_links('mock_domain_1','mock_app_0')),
                           },
                          :messages => [{:text => "RESULT:\nApplication event 'remove-alias' successful"}]
                        }.to_json,
                        :status => 200
                      })

  end

  describe 'alias help' do
    let(:arguments) { ['alias', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.should exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc alias <command> <application> <alias> [--namespace namespace]") }
    end
  end

  describe 'alias add --help' do
    let(:arguments) { ['alias', 'add', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.should exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc alias add <application> <alias> [--namespace namespace]") }
    end
  end

  describe 'alias remove --help' do
    let(:arguments) { ['alias', 'remove', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.should exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc alias remove <application> <alias> [--namespace namespace]") }
    end
  end

  describe 'add alias' do
    let(:arguments) { ['alias', 'add', 'mock_app_0', 'www.foo.bar', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password' ] }
    context 'with no issues' do
      it { expect { run }.should exit_with_code(0) }
    end
  end

  describe 'remove alias' do
    let(:arguments) { ['alias', 'remove', 'mock_app_0', 'www.foo.bar', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password' ] }
    context 'with no issues' do
      it { expect { run }.should exit_with_code(0) }
    end
  end
end
