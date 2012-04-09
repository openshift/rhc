#!/usr/bin/env ruby
# Copyright 2011 Red Hat, Inc.
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'lib/rhc-rest'
require 'test/unit'

class ApplicationTest < Test::Unit::TestCase
  
  def setup
    @random = rand(1000)
    end_point = "https://ec2-23-20-154-157.compute-1.amazonaws.com/broker/rest"
    username = "rhc-rest-test-#{@random}"
    password = "xyz123"
    @client = Rhc::Rest::Client.new(end_point, username, password)
    @domains = []
  end
  
  def teardown
    @client.domains.each do |domain|
      domain.delete(true)
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