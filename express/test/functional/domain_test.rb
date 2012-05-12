require File.expand_path('../../test_helper', __FILE__)

class DomainTest < Test::Unit::TestCase

  setup :with_devenv

  def teardown
    if @client && @client.domains
      @client.domains.each do |domain|
        domain.delete(true)
      end
    end
  end

  def test_create_domain

    domain_name = "rhcrest#{@random}"

    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name

    domains = @client.domains
    assert domains.length == 1
    domain = domains.first
    assert domain.namespace == domain_name

    domains = @client.find_domain(domain_name)
    assert domains.length == 1
    domain = domains.first
    assert domain.namespace == domain_name

  end

  def test_create_multiple_domains

    domain_name = "rhcrest#{@random}"
    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name

    domains = @client.domains
    assert domains.length == 1
    domain = domains.first
    assert domain.namespace == domain_name

    domains = @client.find_domain(domain_name)
    assert domains.length == 1
    domain = domains.first
    assert domain.namespace == domain_name

    domain_name = "rhcrest#{@random}X"
    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name

    domains = @client.domains
    assert domains.length == 2

    domains = @client.find_domain(domain_name)
    assert domains.length == 1
    domain = domains.first
    assert domain.namespace == domain_name
  end

  def test_update_domain

    domain_name = "rhcrest#{@random}"
    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name
    new_domain_name = "rhcrest#{@random}X"
    domain = domain.update(new_domain_name)

    domains = @client.domains
    assert domains.length == 1
    domain = domains.first
    assert domain.namespace == new_domain_name

    domains = @client.find_domain(new_domain_name)
    assert domains.length == 1
    domain = domains.first
    assert domain.namespace == new_domain_name

  end

  def test_update_domain_with_app

    domain_name = "rhcrest#{@random}"
    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name
    app = domain.add_application("app", {:cartridge => "php-5.3"})
    new_domain_name = "rhcrest#{@random}X"
    domain = domain.update(new_domain_name)

    domains = @client.domains
    assert domains.length == 1
    domain = domains.first
    assert domain.namespace == new_domain_name

    domains = @client.find_domain(new_domain_name)
    assert domains.length == 1
    domain = domains.first
    assert domain.namespace == new_domain_name

  end

  def test_delete_domain_with_app

    domain_name = "rhcrest#{@random}"
    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name
    app = domain.add_application("app", {:cartridge => "php-5.3"})
    assert_raise Rhc::Rest::ClientErrorException do
      domain.delete
    end
  end

  def test_force_delete_domain_with_app
    domain_name = "rhcrest#{@random}"
    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name
    app = domain.add_application("app", {:cartridge => "php-5.3"})
    domain.delete(true)
    assert @client.domains.length == 0
  end
end
