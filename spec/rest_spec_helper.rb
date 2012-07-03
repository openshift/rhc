require 'webmock/rspec'

Spec::Matchers.define :have_same_attributes_as do |expected|
  match do |actual|
    (actual.instance_variables == expected.instance_variables) &&
      (actual.instance_variables.map { |i| instance_variable_get(i) } ==
       expected.instance_variables.map { |i| instance_variable_get(i) })
  end
end

module RestSpecHelper
  def mock_user
    "test_user"
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
      link_set[operation] = { 'href' => mock_href(href), 'method' => method }
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
    [['GET_USER',       'user/',       'get' ],
     ['ADD_DOMAIN',     'domains/add', 'post'],
     ['LIST_DOMAINS',   'domains/',    'get' ],
     ['LIST_CARTIDGES', 'cartridges/', 'get' ]]
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
end
