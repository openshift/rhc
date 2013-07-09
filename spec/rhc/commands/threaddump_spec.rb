require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/threaddump'
require 'rhc/config'
describe RHC::Commands::Threaddump do
  let(:client_links)   { mock_response_links(mock_client_links) }
  let(:domain_0_links) { mock_response_links(mock_domain_links('mock_domain_0')) }
  let(:domain_1_links) { mock_response_links(mock_domain_links('mock_domain_1')) }
  let(:app_0_links)    { mock_response_links(mock_app_links('mock_domain_0', 'mock_app_0')) }
  let!(:rest_client){ MockRestClient.new }

  before(:each) do
    user_config
    rest_client.add_domain("mock_domain_0").add_application("mock_app_0", "ruby-1.8.7")
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
    stub_api_request(:post, app_0_links['THREAD_DUMP']['relative'], false).
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
                          :messages => [{:text => 'Application test thread dump complete.: Success', :severity => 'result'}]
                        }.to_json,
                        :status => 200
                      })
  end

  describe 'help' do
    let(:arguments) { ['threaddump', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc threaddump") }
    end
  end

  describe 'threaddump' do
    let(:arguments) { ['threaddump', 'mock_app_0'] }
    it { expect { run }.to exit_with_code(0) }
    it { run_output.should =~ /Application test thread dump complete/ }
  end

  describe 'threaddump no args' do
    let(:arguments) { ['threaddump'] }
    context 'args not supplied' do
      it { expect { run }.to exit_with_code(1) }
    end
  end
end
