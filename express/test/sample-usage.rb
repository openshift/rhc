#!/usr/bin/env ruby
# Copyright 2011 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rhc-rest'


if __FILE__ == $0
  
end_point = ARGV[0]
username = ARGV[1]
password = ARGV[2]
domain_id = ARGV[3]

if end_point.nil? or username.nil? or password.nil? or domain_id.nil?
  puts "Usage: https://<hostname>/broker/rest <username> <password> <domain_id>"
  exit 1
end
@mydebug =true
client = Rhc::Rest::Client.new(end_point, username, password)

client.domains.each do |domain|
  domain.applications.each do |app|
    app.delete
  end
  domain.delete
end
puts "Creating a domain"
domain = client.add_domain(domain_id)
puts "Domain created: #{domain.id}"

puts "Getting all cartridges..."
client.cartridges.each do |cart|
  puts "  #{cart.name} (type: #{cart.type})"
end

puts "Creating application appone"
carts = client.find_cartridge("php-5.3")
domain.add_application("appone", {:cartridge => carts.first.name})

puts "Try deleting domain with an application"
begin
  domain.delete
rescue Exception => e
  puts e.message
end

puts "Getting all domains and applications..."
client.domains.each do |domain|
  puts "  Domain: #{domain.id}"
  domain.applications.each do |app|
    puts "    Application: #{app.name}"
    app.cartridges.each do |cart|
      puts "      Cartridge #{cart.name} (#{cart.type})"
    end
  end
end

puts "Find application=appone and restart it..."
apps = client.find_application("appone")
apps.first.restart

apps = client.find_application("appthree")
if not apps.nil? and not apps.first.nil?
  apps.first.delete
end

puts "Create new application named appthree..."
app = client.domains.first.add_application("appthree", {:cartridge =>"php-5.3"})
puts "Adding MySQL cartridge to appthree"
cartridge = app.add_cartridge("mysql-5.1")
puts "Check to see if it was added"
app.cartridges.each do |cart|
  puts "Cartridge #{cart.name} (#{cart.type})"
end

puts "Restart MySQL cartridge"
cartridge.restart
puts "Deleting MySQL cartridge"
cartridge.delete
puts "Check to see if it was deleted"
if app.cartridges.size == 0
  puts "MySQL cartridge is deleted"
end
puts "Deleting appthree"
app.delete
end

puts "Adding, updating and deleting keys"
key = client.user.add_key("newkey", "NEWKEYCONTENT", "ssh-rsa")

puts "Added key: #{key.name} updating key content"
key.update(key.type, "NEWKEYCONTENT123")

puts "Getting all keys..."
client.user.keys.each do |key|
  puts "  Key: #{key.name} (type: #{key.type}) #{key.content}"
end

puts "Deleting key"
begin
  key.delete
rescue Exception => e
  puts e.message
end

puts 'Clean up domains and apps by force deleting domain'
client.domains.each do |domain|
  domain.delete(true)
end

