require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/alias'
require 'rhc/config'

describe RHC::Commands::Alias do
  let(:client_links)   { mock_response_links(mock_client_links) }
  let(:domain_0_links) { mock_response_links(mock_domain_links('mock_domain_0')) }
  let(:domain_1_links) { mock_response_links(mock_domain_links('mock_domain_1')) }
  let(:app_0_links)    { mock_response_links(mock_app_links('mock_domain_0', 'mock_app_0')) }
  let(:alias_0_links)  { mock_response_links(mock_alias_links('mock_domain_0', 'mock_app_0', 'www.foo.bar')) }
  let!(:rest_client){ MockRestClient.new }
  before(:each) do
    user_config
    domain = rest_client.add_domain("mock_domain_0")
    domain.add_application("mock_app_0", "ruby-1.8.7").add_alias("www.foo.bar")
    domain.add_application("mock_app_1", "ruby-1.8.7")
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
    stub_api_request(:any, app_0_links['ADD_ALIAS']['relative'], false).
            with(:body => {:event => 'add-alias', :alias => 'www.foo.bar'}).
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
    stub_api_request(:any, app_0_links['REMOVE_ALIAS']['relative'], false).
            with(:body => {:event => 'remove-alias', :alias => 'www.foo.bar'}).
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
    stub_api_request(:any, app_0_links['LIST_ALIASES']['relative'], false).
            to_return({ :body   => {
                    :type => 'aliases',
                    :data =>
                    [{ :domain_id                   => 'mock_domain_0',
                       :application_id              => 'mock_app_0',
                       :id                          => 'www.foo.bar',
                       :certificate_added_at        => nil,
                       :has_private_ssl_certificate => false,
                       :links                       => mock_response_links(mock_alias_links('mock_domain_0','mock_app_0', 'www.foo.bar')),
                     }]
                  }.to_json,
                  :status => 200
                })

  end

  describe 'alias help' do
    let(:arguments) { ['alias', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc alias <action>$") }
    end
  end

  describe 'alias add --help' do
    let(:arguments) { ['alias', 'add', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc alias-add <application> <alias> [--namespace NAME]") }
    end
  end

  describe 'alias remove --help' do
    let(:arguments) { ['alias', 'remove', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc alias-remove <application> <alias> [--namespace NAME]") }
    end
  end

  describe 'alias update-cert --help' do
    let(:arguments) { ['alias', 'update-cert', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc alias-update-cert <application> <alias> --certificate FILE --private-key FILE [--passphrase passphrase]") }
    end
  end

  describe 'alias delete-cert --help' do
    let(:arguments) { ['alias', 'delete-cert', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc alias-delete-cert <application> <alias>") }
    end
  end

  describe 'alias list --help' do
    let(:arguments) { ['alias', 'list', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc alias-list <application>") }
    end
  end

  describe 'add alias' do
    let(:arguments) { ['alias', 'add', 'mock_app_0', 'www.foo.bar' ] }
    it { expect { run }.to exit_with_code(0) }
    it { run_output.should =~ /Alias 'www.foo.bar' has been added/m }
  end

  describe 'add alias with implicit context' do
    before{ subject.class.any_instance.stub(:git_config_get){ |key| case key; when 'rhc.app-name' then 'mock_app_0'; when 'rhc.domain-name' then 'mock_domain_0'; end } }
    let(:arguments) { ['alias', 'add', '--', 'www.foo.bar' ] }
    it { expect { run }.to exit_with_code(0) }
    it { run_output.should =~ /Alias 'www.foo.bar' has been added/m }
  end

  describe 'remove alias' do
    before do 
      rest_client.stub(:api_version_negotiated).and_return(1.4)
    end
    context 'remove alias successfully' do
      let(:arguments) { ['alias', 'remove', 'mock_app_0', 'www.foo.bar' ] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /Alias 'www.foo.bar' has been removed/m }
    end
    context 'remove alias with server api <= 1.3' do
      let(:arguments) { ['alias', 'remove', 'mock_app_0', 'www.foo.bar' ] }
      before do 
        rest_client.stub(:api_version_negotiated).and_return(1.3)
      end
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /Alias 'www.foo.bar' has been removed/m }
    end
  end

  describe 'alias update-cert' do
    before do 
      rest_client.stub(:api_version_negotiated).and_return(1.4)
    end
    context 'add valid certificate with valid private key without pass phrase' do
      let(:arguments) { ['alias', 'update-cert', 'mock_app_0', 'www.foo.bar', 
        '--certificate', File.expand_path('../../assets/cert.crt', __FILE__),
        '--private-key', File.expand_path('../../assets/cert_key_rsa', __FILE__) ] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /SSL certificate successfully added/m }
    end
    context 'cert file not found' do
      let(:arguments) { ['alias', 'update-cert', 'mock_app_0', 'www.foo.bar', 
        '--certificate', File.expand_path('../../assets/nothing.foo', __FILE__),
        '--private-key', File.expand_path('../../assets/cert_key_rsa', __FILE__) ] }
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /Certificate file not found/m }
    end
    context 'private key file not found' do
      let(:arguments) { ['alias', 'update-cert', 'mock_app_0', 'www.foo.bar', 
        '--certificate', File.expand_path('../../assets/cert.crt', __FILE__),
        '--private-key', File.expand_path('../../assets/nothing.foo', __FILE__) ] }
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /Private key file not found/m }
    end
    context 'not existing certificate alias' do
      let(:arguments) { ['alias', 'update-cert', 'mock_app_0', 'www.unicorns.com', 
        '--certificate', File.expand_path('../../assets/cert.crt', __FILE__),
        '--private-key', File.expand_path('../../assets/cert_key_rsa', __FILE__) ] }
      it { expect { run }.to exit_with_code(156) }
      it { run_output.should =~ /Alias www.unicorns.com can't be found in application/m }
    end
    context 'fails if server does not support' do
      let(:arguments) { ['alias', 'update-cert', 'mock_app_0', 'www.foo.bar', 
        '--certificate', File.expand_path('../../assets/cert.crt', __FILE__),
        '--private-key', File.expand_path('../../assets/cert_key_rsa', __FILE__) ] }
      before do 
        rest_client.stub(:api_version_negotiated).and_return(1.3)
      end
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /The server does not support SSL certificates for custom aliases/m }
    end
    context 'invalid certificate file (empty)' do
      let(:arguments) { ['alias', 'update-cert', 'mock_app_0', 'www.foo.bar', 
        '--certificate', File.expand_path('../../assets/empty.txt', __FILE__),
        '--private-key', File.expand_path('../../assets/cert_key_rsa', __FILE__) ] }
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /Invalid certificate file/m }
    end
    context 'invalid private key file (empty)' do
      let(:arguments) { ['alias', 'update-cert', 'mock_app_0', 'www.foo.bar', 
        '--certificate', File.expand_path('../../assets/cert.crt', __FILE__),
        '--private-key', File.expand_path('../../assets/empty.txt', __FILE__) ] }
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /Invalid private key file/m }
    end
  end

  describe 'alias delete-cert' do
    before do 
      rest_client.stub(:api_version_negotiated).and_return(1.4)
    end
    context 'delete existing certificate' do
      let(:arguments) { ['alias', 'delete-cert', 'mock_app_0', 'www.foo.bar', '--confirm'] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /SSL certificate successfully deleted/m }
    end
    context 'delete not existing certificate' do
      let(:arguments) { ['alias', 'delete-cert', 'mock_app_0', 'www.unicorns.com', '--confirm'] }
      it { expect { run }.to exit_with_code(156) }
      it { run_output.should =~ /Alias www.unicorns.com can't be found in application mock_app_0/m }
    end
    context 'fails if server does not support' do
      let(:arguments) { ['alias', 'delete-cert', 'mock_app_0', 'www.foo.bar', '--confirm'] }
      before do 
        rest_client.stub(:api_version_negotiated).and_return(1.3)
      end
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /The server does not support SSL certificates for custom aliases/m }
    end
  end

  describe 'alias list' do
    before do 
      rest_client.stub(:api_version_negotiated).and_return(1.4)
    end
    context 'list app with existing certificate' do
      let(:arguments) { ['alias', 'list', 'mock_app_0'] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /Has Certificate?/m }
      it { run_output.should =~ /Certificate Added/m }
      it { run_output.should =~ /www.foo.bar/m }
    end
    context 'list app without certificates' do
      let(:arguments) { ['alias', 'list', 'mock_app_1'] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /No aliases associated with the application mock_app_1/m }
    end
    context 'simple list is server does not support ssl certs' do
      let(:arguments) { ['alias', 'list', 'mock_app_0'] }
      before do 
        rest_client.stub(:api_version_negotiated).and_return(1.3)
      end
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /no/m }
      it { run_output.should =~ /-/m }
      it { run_output.should =~ /www.foo.bar/m }
    end
  end

  describe 'aliases' do
    before do 
      rest_client.stub(:api_version_negotiated).and_return(1.4)
    end
    context 'app with existing certificate' do
      let(:arguments) { ['aliases', 'mock_app_0'] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /Has Certificate?/m }
      it { run_output.should =~ /Certificate Added/m }
      it { run_output.should =~ /www.foo.bar/m }
    end
    context 'app without certificates' do
      let(:arguments) { ['aliases', 'mock_app_1'] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /No aliases associated with the application mock_app_1/m }
    end
    context 'simple list is server does not support ssl certs' do
      let(:arguments) { ['aliases', 'mock_app_0'] }
      before do 
        rest_client.stub(:api_version_negotiated).and_return(1.3)
      end
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /no/m }
      it { run_output.should =~ /-/m }
      it { run_output.should =~ /www.foo.bar/m }
    end
  end

end
