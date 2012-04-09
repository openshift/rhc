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

class DomainTest < Test::Unit::TestCase
  
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