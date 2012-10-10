require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/threaddump'
require 'rhc/config'
describe RHC::Commands::Threaddump do
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
    stub_api_request(:any, app_0_links['THREAD_DUMP']['relative']).with(:body => {:event => 'thread-dump'}, :headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'17', 'Content-Type'=>'application/x-www-form-urlencoded'}).
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
                          :messages => [{:text => 'Application test thread dump complete.: Success'}]
                        }.to_json,
                        :status => 200
                      })
  end

  describe 'help' do
    let(:arguments) { ['threaddump', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.should exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc threaddump") }
    end
  end

  describe 'threaddump' do
    let(:arguments) { ['threaddump', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'mock_app_0'] }
    context 'with no issues' do
      it { expect { run }.should exit_with_code(0) }
    end
  end
  describe 'threaddump no args' do
    let(:arguments) { ['threaddump', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
    context 'args not supplied' do
      it { expect { run }.should exit_with_code(1) }
    end
  end
end
