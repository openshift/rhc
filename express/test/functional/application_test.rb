require File.expand_path('../../test_helper', __FILE__)

class ApplicationTest < Test::Unit::TestCase
  setup :with_devenv

  def teardown
    if @client && @client.domains
      @client.domains.each do |domain|
        domain.delete(true)
      end
    end
  end

  def test_create_app
    domain_name = "rhcrest#{@random}"
    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name
    app = domain.add_application("app", {:cartridge => "php-5.3"})
    puts app
    assert app.name == "app", "application name is not equal "
    puts app.framework
    assert app.framework == "php-5.3"
    apps = @client.find_application("app")
    assert apps.length == 1
    assert apps.first.name == "app"
  end
=begin
  def test_create_scalable_app
    domain_name = "rhcrest#{@random}"
    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name
    app = domain.add_application("app", {:cartridge => "php-5.3", :scale => true})
    assert app.name == "app"
    assert app.framework == "php-5.3"
    assert app.scalable == true
    apps = @client.find_application("app")
    assert apps.length == 1
    assert apps.first.name == "app"
  end

  def test_create_app_with_small_node
    domain_name = "rhcrest#{@random}"
    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name
    app = domain.add_application("app", {:cartridge => "php-5.3", :node_profile => "small"})
    assert app.name == "app"
    assert app.framework == "php-5.3"
    assert app.node_profile = "small"
    apps = @client.find_application("app")
    assert apps.length == 1
    assert apps.first.name == "app"

  end

  def test_create_scalable_app_with_small_node
    domain_name = "rhcrest#{@random}"
    domain = @client.add_domain(domain_name)
    assert domain.namespace == domain_name
    app = domain.add_application("app", {:cartridge => "php-5.3", :scale => true, :node_profile => "small"})
    assert app.name == "app"
    assert app.framework == "php-5.3"
    assert app.node_profile = "small"
    assert app.scalable == true
    apps = @client.find_application("app")
    assert apps.length == 1
    assert apps.first.name == "app"
  end
=end

end
