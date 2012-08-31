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
      b64encode(value, value.length).strip
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
    end

    def domains
      @domains
    end

    def cartridges
      [MockRestCartridge.new("mock_cart-1", "mock_cart_type-1"),
       MockRestCartridge.new("mock_cart-2", "mock_cart_type-2"),
       MockRestCartridge.new("unique_mock_cart-1", "unique_mock_cart_type-1")]
    end

    def add_domain(id)
      d = MockRestDomain.new(id, self)
      @domains << d
      d
    end
  end

  class MockRestDomain < RHC::Rest::Domain
    attr_reader :id

    def initialize(id, client)
      @id = id
      @client = client
      @applications = []
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

    def add_application(name, type=nil)
      a = MockRestApplication.new(name, type, self)
      @applications << a
      a
    end

    def applications
      @applications
    end
  end

  class MockRestApplication < RHC::Rest::Application
    attr_reader :name, :uuid, :creation_time, :git_url, :app_url, :aliases

    def initialize(name, type, domain)
      @name = name
      @domain = domain
      @cartridges = []
      @creation_time = "now"
      @uuid = "fakeuuidfortests"
      @git_url = "git:fake.foo/git/#{@name}.git"
      @app_url = "https://#{@name}-#{@domain.id}.fake.foo/"
      @aliases = []
      add_cartridge(type, false) if type
    end

    def add_cartridge(name, embedded=true)
      type = embedded ? "embedded" : "framework"
      c = MockRestCartridge.new(name, type, self)
      @cartridges << c
      c
    end

    def cartridges
      @cartridges
    end
  end

  class MockRestCartridge < RHC::Rest::Cartridge
    attr_reader :name
    attr_reader :type
    attr_reader :properties

    def initialize(name, type, app=nil, properties={:cart_data => {:connection_url => {'value' => "http://fake.url" }}})
      @name = name
      @type = type
      @app = app
      @properties = properties
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
end
