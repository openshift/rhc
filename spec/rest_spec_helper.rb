require 'webmock/rspec'
require 'rhc/rest'
require 'rhc/exceptions'
require 'base64'

Spec::Matchers.define :have_same_attributes_as do |expected|
  match do |actual|
    (actual.instance_variables == expected.instance_variables) &&
      (actual.instance_variables.map { |i| instance_variable_get(i) } ==
       expected.instance_variables.map { |i| instance_variable_get(i) })
  end
end

# ruby 1.8 does not have strict_encode
if RUBY_VERSION.to_f == 1.8
  module Base64
    def strict_encode64(value)
      encode64(value).delete("\n")
    end
  end
end

module RestSpecHelper
  def mock_user
    "test_user"
  end

  def stub_api_request(method, uri, with_auth=true)
    stub_request(method, mock_href(uri, with_auth)).
      with(&user_agent_header)
  end

  def mock_pass
    "test pass"
  end

  def mock_uri
    "test.domain.com"
  end

  # Creates consistent hrefs for testing
  def mock_href(relative="", with_auth=false)
    uri_string = mock_uri
    if (with_auth == true)
      uri_string = mock_user + ":" + mock_pass + "@" + mock_uri
    end
    "https://#{uri_string}/#{relative}"
  end

  # This formats link lists for JSONification
  def mock_response_links(links)
    link_set = {}
    links.each do |link|
      operation = link[0]
      href      = link[1]
      method    = link[2]
      # Note that the 'relative' key/value pair below is a convenience for testing;
      # this is not used by the API classes.
      link_set[operation] = { 'href' => mock_href(href), 'method' => method, 'relative' => href }
    end
    return link_set
  end

  def mock_app_links(domain_id='test_domain',app_id='test_app')
    [['ADD_CARTRIDGE',   "domains/#{domain_id}/apps/#{app_id}/carts/add", 'post'],
     ['LIST_CARTRIDGES', "domains/#{domain_id}/apps/#{app_id}/carts/",    'get' ],
     ['START',           "domains/#{domain_id}/apps/#{app_id}/start",     'post'],
     ['STOP',            "domains/#{domain_id}/apps/#{app_id}/stop",      'post'],
     ['RESTART',         "domains/#{domain_id}/apps/#{app_id}/restart",   'post'],
     ['THREAD_DUMP',     "domains/#{domain_id}/apps/#{app_id}/event",     'post'],
     ['DELETE',          "domains/#{domain_id}/apps/#{app_id}/delete",    'post']]
  end

  def mock_cart_links(domain_id='test_domain',app_id='test_app',cart_id='test_cart')
    [['START',   "domains/#{domain_id}/apps/#{app_id}/carts/#{cart_id}/start",   'post'],
     ['STOP',    "domains/#{domain_id}/apps/#{app_id}/carts/#{cart_id}/stop",    'post'],
     ['RESTART', "domains/#{domain_id}/apps/#{app_id}/carts/#{cart_id}/restart", 'post'],
     ['DELETE',  "domains/#{domain_id}/apps/#{app_id}/carts/#{cart_id}/delete",  'post']]
  end

  def mock_client_links
    [['GET_USER',        'user/',       'get' ],
     ['ADD_DOMAIN',      'domains/add', 'post'],
     ['LIST_DOMAINS',    'domains/',    'get' ],
     ['LIST_CARTRIDGES', 'cartridges/', 'get' ]]
  end

  def mock_domain_links(domain_id='test_domain')
    [['ADD_APPLICATION',   "domains/#{domain_id}/apps/add", 'post'],
     ['LIST_APPLICATIONS', "domains/#{domain_id}/apps/",    'get' ],
     ['UPDATE',            "domains/#{domain_id}/update",   'post'],
     ['DELETE',            "domains/#{domain_id}/delete",   'post']]
  end

  def mock_key_links(key_id='test_key')
    [['UPDATE', "user/keys/#{key_id}/update", 'post'],
     ['DELETE', "user/keys/#{key_id}/delete", 'post']]
  end

  def mock_user_links
    [['ADD_KEY',   'user/keys/add', 'post'],
     ['LIST_KEYS', 'user/keys/',    'get' ]]
  end

  def mock_cartridge_response(cart_count=1)
    carts = []
    while carts.length < cart_count
      carts << {
        :name  => "mock_cart_#{carts.length}",
        :type  => "mock_cart_#{carts.length}_type",
        :links => mock_response_links(mock_cart_links('mock_domain','mock_app',"mock_cart_#{carts.length}"))
      }
    end

    carts = carts[0] if cart_count == 1
    type  = cart_count == 1 ? 'cartridge' : 'cartridges'

    return {
      :body   => {
        :type => type,
        :data => carts
      }.to_json,
      :status => 200
    }
  end

  class MockRestClient < RHC::Rest::Client
    def initialize
      RHC::Rest::Client.stub(:new) { self }
      @domains = []
      @keys = [
        MockRestKey.new('mockkey1', 'ssh-rsa', 'AAAAB3NzaC1yc2EAAAADAQABAAABAQDNK8xT3O+kSltmCMsSqBfAgheB3YFJ9Y0ESJnFjFASVxH70AcCQAgdQSD/r31+atYShJdP7f0AMWiQUTw2tK434XSylnZWEyIR0V+j+cyOPdVQlns6D5gPOnOtweFF0o18YulwCOK8Q1H28GK8qyWhLe0FcMmxtKbbQgaVRvQdXZz4ThzutCJOyJm9xVb93+fatvwZW76oLLvfFJcJSOK2sgW7tJM2A83bm4mwixFDF7wO/+C9WA+PgPKJUIjvy1gZjBhRB+3b58vLOnYhPOgMNruJwzB+wJ3pg8tLJEjxSbHyyoi6OqMBs4BVV7LdzvwTDxEjcgtHVvaVNXgO5iRX'),
        MockRestKey.new('mockkey2', 'ssh-dsa', 'AAAAB3NzaC1kc3MAAACBAPaaFj6Xjrjd8Dc4AAkJe0HigqaXMxj/87xHoV+nPgerHIceJWhPUWdW40lSASrgpAV9Eq4zzD+L19kgYdbMw0vSX5Cj3XtNOsow9MmMxFsYjTxCv4eSs/rLdGPaYZ5GVRPDu8tN42Bm8lj5o+ky3HzwW+mkQMZwcADQIgqtn6QhAAAAFQCirDfIMf/JoMOFf8CTnsTKWw/0zwAAAIAIQp6t2sLIp1d2TBfd/qLjOJA10rPADcnhBzWB/cd/oFJ8a/2nmxeSPR5Ov18T6itWqbKwvZw2UC0MrXoYbgcfVNP/ym1bCd9rB5hu1sg8WO4JIxA/47PZooT6PwTKVxHuENEzQyJL2o6ZJq+wuV0taLvm6IaM5TAZuEJ2p4TC/gAAAIBpLcVXZREa7XLY55nyidt/+UC+PxpjhPHOHbzL1OvWEaumN4wcJk/JZPppgXX9+WDkTm1SD891U0cXnGMTP0OZOHkOUHF2ZcfUe7p9kX4WjHs0OccoxV0Lny6MC4DjalJyaaEbijJHSUX3QlLcBOlPHJWpEpvWQ9P8AN4PokiGzA==')
      ]
      @__json_args__= {:links => mock_response_links(mock_client_links)}
    end

    def domains
      @domains
    end

    def cartridges
      [MockRestCartridge.new("mock_standalone_cart-1", "standalone"),
       MockRestCartridge.new("mock_cart-1", "embedded"),
       MockRestCartridge.new("mock_cart-2", "embedded"),
       MockRestCartridge.new("unique_mock_cart-1", "embedded")]
    end

    def add_domain(id)
      d = MockRestDomain.new(id, self)
      @domains << d
      d
    end
    
    def sshkeys
      @keys
    end
    
    def find_key(name)
      # RHC::Rest::Client#find_key(name) returns the first (and only) key
      @keys.select { |key| key.name == name }.first
    end
    
    def add_key(name, type, content)
      @keys << MockRestKey.new(name, type, content)
    end
    
    def delete_key(name)
      @keys.delete_if { |key| key.name == name }
    end
  end

  class MockRestDomain < RHC::Rest::Domain
    def initialize(id, client)
      @id = id
      @client = client
      @applications = []
      @__json_args__= {:links => mock_response_links(mock_domain_links('mock_domain_0'))}
    end

    def update(id)
      @id = id
      self
    end

    def destroy
      raise RHC::Rest::ClientErrorException.new("Applications must be empty.") unless @applications.empty?
      @client.domains.delete_if { |d| d.id == @id }

      @client = nil
      @applications = nil
    end

    def add_application(name, type=nil, scale=nil)
      a = MockRestApplication.new(name, type, self, scale)
      @applications << a
      a
    end

    def applications
      @applications
    end
  end

  class MockRestApplication < RHC::Rest::Application
    def fakeuuid
      "fakeuuidfortests#{@name}"
    end

    def initialize(name, type, domain, scale=nil)
      @name = name
      @domain = domain
      @cartridges = []
      @creation_time = "now"
      @uuid = fakeuuid
      @git_url = "git:fake.foo/git/#{@name}.git"
      @app_url = "https://#{@name}-#{@domain.id}.fake.foo/"
      @ssh_url = "ssh://#{@uuid}@127.0.0.1"
      @embedded = {}
      @aliases = []
      if scale
        @scalable = true
        @embedded = {"haproxy-1.4" => {:info => ""}}
      end
      @__json_args__= {:links => mock_response_links(mock_app_links('mock_domain_0', 'mock_app_0'))}
      add_cartridge(type, false) if type
    end

    def add_cartridge(name, embedded=true)
      type = embedded ? "embedded" : "standalone"
      c = MockRestCartridge.new(name, type, self)
      @cartridges << c
      c
    end

    def cartridges
      @cartridges
    end
  end

  class MockRestCartridge < RHC::Rest::Cartridge
    def initialize(name, type, app=nil, properties={:cart_data => {:connection_url => {'name' => 'connection_url', 'value' => "http://fake.url" }}})
      @name = name
      @type = type
      @app = app
      @properties = properties
    end

    def destroy
      @app.cartridges.delete self
    end

    def start
      @app
    end

    def stop
      @app
    end

    def restart
      @app
    end

    def reload
      @app
    end
  end

  class MockRestKey < RHC::Rest::Key
    def initialize(name, type, content)
      @name    = name
      @type    = type
      @content = content
    end
  end
end
