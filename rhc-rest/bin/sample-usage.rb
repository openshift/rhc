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

require '../lib/rhc-rest'
require '../lib/rhc-rest/client'
require '../lib/rhc-rest/domain'

if __FILE__ == $0

end_point = "https://23.20.70.28/broker/rest"
username = "lnader"
paswword = "xyz123"

client = Rhc::Rest::Client.new(end_point, username, paswword)

puts "Getting all domains and applications..."
client.domains.each do |domain|
  puts "Domain: #{domain.namespace}"
  domain.applications.each do |app|
    puts "  Application: #{app.name}"
    app.cartridges.each do |cart|
      puts "    Cartridge #{cart.name} (#{cart.type})"
    end
  end
end


puts "Getting all cartridges..."
client.cartridges.each do |cart|
  puts "Cartridge: #{cart.name} (type: #{cart.type})"
end

puts "Find application=appone and restart it..."
apps = client.find_application("appone")
apps.first.restart

client.find_application("appthree").first.delete

puts "Create new application named appthree..."
carts = client.find_cartridge("php-5.3")
app = client.domains.first.add_application("appthree", carts.first.name)
puts "Adding MySQL cartridge to appthree"
cartridge = app.add_cartridge("mysql-5.1")
puts "Check to see if it was added"
app.cartridges.each do |cart|
  puts "Cartridge #{cart.name} (#{cart.type})"
end
puts "Restart MySQL cartridge"
cartridge.restart
puts "Deleting MySql cartridge"
cartridge.delete
puts "Check to see if it was deleted"
puts app.cartridges.size
puts "Deleting appthree"
app.delete
end
return
puts "Getting all keys..."
client.user.keys.each do |key|
  puts "Key: #{key.name} (type: #{key.type}) #{key.content}"
end

puts "Adding, updating and deleting keys"
key = client.user.add_key("newkey", "NEWKEYCONTENT", "ssh-rsa")
puts "Added key: #{key.name} now changing it's name to 'renamed-newkey'"
key.update({:name => "renamed-newkey", :content => key.content, :type => key.type})
key.delete

puts "Finding a key and deleting it"
keys = client.user.find_key("newkey")
keys.first.delete unless keys.first.nil?

