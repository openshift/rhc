# Copyright 2010 Red Hat, Inc.
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

require 'rubygems'
require 'fileutils'
require 'getoptlong'
require 'json'
require 'net/http'
require 'net/https'
require 'parseconfig'
require 'resolv'
require 'uri'


module RHC

  Maxdlen = 16
  Maxretries = 7
  Defaultdelay = 2
  API = "1.1.1"
  broker_version = "?.?.?"
  api_version = "?.?.?"

  def self.update_server_api_v(dict)
    if !dict['broker'].nil? && (dict['broker'] =~ /\A\d+\.\d+\.\d+\z/)
      broker_version = dict['broker']
    end
    if !dict['api'].nil? && (dict['api'] =~ /\A\d+\.\d+\.\d+\z/)
      api_version = dict['api']
    end
  end

  def self.delay(time, adj=Defaultdelay)
    (time*=adj).to_int
  end

  def self.generate_json(data)
      data['api'] = API
      json = JSON.generate(data)
      json
  end

  def self.get_cartridges_list(libra_server, net_http, cart_type="standalone", debug=true, print_result=nil)
    puts "Contacting https://#{libra_server} to obtain list of cartridges..."
    puts " (please excuse the delay)"
    data = {'cart_type' => cart_type}
    if debug
      data['debug'] = "true"
    end
    print_post_data(data, debug)
    json_data = generate_json(data)

    url = URI.parse("https://#{libra_server}/broker/cartlist")
    response = http_post(net_http, url, json_data, "none")

    unless response.code == '200'
      print_response_err(response, debug)
      return []
    end
    begin
      json_resp = JSON.parse(response.body)
    rescue JSON::ParserError
      exit 254
    end
    update_server_api_v(json_resp)
    if print_result
      print_response_success(json_resp, debug)
    end
    begin
      carts = (JSON.parse(json_resp['data']))['carts']
    rescue JSON::ParserError
      exit 254
    end
    carts
  end

  def self.get_cartridge_listing(carts, sep, libra_server, net_http, cart_type="standalone", debug=true, print_result=nil)
    carts = get_cartridges_list(libra_server, net_http, cart_type, debug, print_result) if carts.nil?
    carts.join(sep)
  end


  # Invalid chars (") ($) (^) (<) (>) (|) (%) (/) (;) (:) (,) (\) (*) (=) (~)
  def self.check_rhlogin(rhlogin)
    if rhlogin
      if rhlogin.length < 6
        puts 'RHLogin must be at least 6 characters'
        return false
      elsif rhlogin =~ /["\$\^<>\|%\/;:,\\\*=~]/
        puts 'RHLogin may not contain any of these characters: (\") ($) (^) (<) (>) (|) (%) (/) (;) (:) (,) (\) (*) (=) (~)'
        return false
      end
    else
      puts "RHLogin is required"
      return false
    end
    true
  end

  def self.check_app(app)
    check_field(app, 'application', Maxdlen)
  end

  def self.check_namespace(namespace)
    check_field(namespace, 'namespace', Maxdlen)
  end

  def self.check_field(field, type, max=0)
    if field
      if field =~ /[^0-9a-zA-Z]/
        puts "#{type} contains non-alphanumeric characters!"
        return false
      end
      if max != 0 && field.length > Maxdlen
        puts "maximum #{type} size is #{Maxdlen} characters"
        return false
      end
    else
      puts "#{type} is required"
      return false
    end
    true
  end

  def self.print_post_data(h, debug)
    if (debug)
      puts 'Submitting form:'
      h.each do |k,v|
        if k.to_s != 'password'
          puts "#{k.to_s}: #{v.to_s}"
        else
          print 'password: '
          for i in (1..v.length)
            print 'X'
          end
          puts ''
        end
      end
    end
  end

  def self.get_user_info(libra_server, rhlogin, password, net_http, debug, print_result, not_found_message=nil)

    puts "Contacting https://#{libra_server}"
    data = {'rhlogin' => rhlogin}
    if debug
      data['debug'] = "true"
    end
    print_post_data(data, debug)
    json_data = generate_json(data)

    url = URI.parse("https://#{libra_server}/broker/userinfo")
    response = http_post(net_http, url, json_data, password)

    unless response.code == '200'
      if response.code == '404'
        if not_found_message
          puts not_found_message
        else
          puts "A user with rhlogin '#{rhlogin}' does not have a registered domain.  Be sure to run rhc-create-domain before using the other rhc tools."
        end
        exit 99
      elsif response.code == '401'
        puts "Invalid user credentials"
        exit 97
      else
        print_response_err(response, debug)
      end
      exit 254
    end
    begin
      json_resp = JSON.parse(response.body)
    rescue JSON::ParserError
      exit 254
    end
    update_server_api_v(json_resp)
    if print_result
      print_response_success(json_resp, debug)
    end
    begin
      user_info = JSON.parse(json_resp['data'].to_s)
    rescue JSON::ParserError
      exit 254
    end
    user_info
  end

  def self.get_password
    password = nil
    begin
      print "Password: "
      system "stty -echo"
      password = gets.chomp
    ensure
      system "stty echo"
    end
    puts "\n"
    password
  end

  def self.http_post(http, url, json_data, password)
    req = http::Post.new(url.path)

    req.set_form_data({'json_data' => json_data, 'password' => password})
    http = http.new(url.host, url.port)
    http.open_timeout = 10
    if url.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    begin
      response = http.start {|http| http.request(req)}
      if response.code == '404' && response.content_type == 'text/html'
        # TODO probably want to remove this at some point
        puts "!!!! WARNING !!!! WARNING !!!! WARNING !!!!"
        puts "RHCloud server not found.  You might want to try updating your rhc client tools."
        exit 218
      end
      response
    rescue Exception => e
      puts "There was a problem communicating with the server. Response message: #{e.message}"
      puts "If you were disconnected it is possible the operation finished without being able to report success."
      puts "You can use rhc-user-info and rhc-ctl-app to learn about the status of your user and application(s)."
      exit 219
    end
  end

  def self.print_response_err(response, debug)
    puts "Problem reported from server. Response code was #{response.code}."
    if (!debug)
      puts "Re-run with -d for more information."
    end
    exit_code = 254
    if response.content_type == 'application/json'
      puts "JSON response:"
      begin
        json_resp = JSON.parse(response.body)
        exit_code = print_json_body(json_resp, debug)
      rescue JSON::ParserError
        exit_code = 254
      end
    elsif debug
      puts "HTTP response from server is #{response.body}"
    end
    exit exit_code.nil? ? 666 : exit_code
  end

  def self.print_response_messages(json_resp)
    messages = json_resp['messages']
    if (messages && !messages.empty?)
      puts ''
      puts 'MESSAGES:'
      puts messages
      puts ''
    end
  end

  def self.print_response_success(json_resp, debug, always_print_result=false)
    if debug
      puts "Response from server:"
      print_json_body(json_resp, debug)
    elsif always_print_result
      print_json_body(json_resp, debug)
    else
      print_response_messages(json_resp)
    end
  end

  def self.print_json_body(json_resp, debug)
    print_response_messages(json_resp)
    exit_code = json_resp['exit_code']
    if debug
      if json_resp['debug']
        puts ''
        puts 'DEBUG:'
        puts json_resp['debug']
        puts ''
        puts "Exit Code: #{exit_code}"
        if (json_resp.length > 3)
          json_resp.each do |k,v|
            if (k != 'result' && k != 'debug' && k != 'exit_code' && k != 'messages' && k != 'data')
              puts "#{k.to_s}: #{v.to_s}"
            end
          end
        end
      end
    end
    if json_resp['api']
      puts "API version:    #{json_resp['api']}"
    end
    if json_resp['broker']
      puts "Broker version: #{json_resp['broker']}"
    end
    if json_resp['result']
      puts ''
      puts 'RESULT:'
      puts json_resp['result']
      puts ''
    end
    exit_code
  end

  #
  # Check if host exists
  #
  def self.hostexist?(host)
      dns = Resolv::DNS.new
      resp = dns.getresources(host, Resolv::DNS::Resource::IN::A)
      return resp.any?
  end

end

#
# Config paths... /etc/openshift/express.conf or $GEM/conf/express.conf -> ~/.openshift/express.conf
#
# semi-private: Just in case we rename again :)
@conf_name = 'express.conf'
_linux_cfg = '/etc/openshift/' + @conf_name
_gem_cfg = File.join(File.expand_path(File.dirname(__FILE__) + "/../conf"), @conf_name)
_home_conf = File.expand_path('~/.openshift')
@local_config_path = File.join(_home_conf, @conf_name)
@config_path = File.exists?(_linux_cfg) ? _linux_cfg : _gem_cfg

FileUtils.mkdir_p _home_conf unless File.directory?(_home_conf)
local_config_path = File.expand_path(@local_config_path)
if !File.exists? local_config_path
  FileUtils.touch local_config_path
  puts ""
  puts "Created local config file: " + local_config_path
  puts "express.conf contains user configuration and can be transferred across clients."
  puts ""
end

begin
  @global_config = ParseConfig.new(@config_path)
  @local_config = ParseConfig.new(File.expand_path(@local_config_path))
rescue Errno::EACCES => e
  puts "Could not open config file: #{e.message}"
  exit 253
end

#
# Check for proxy environment
#
if ENV['http_proxy']
  host, port = ENV['http_proxy'].split(':')
  @http = Net::HTTP::Proxy(host, port)
else
  @http = Net::HTTP
end

#
# Check for local var in
#   1) ~/.openshift/express.conf
#   2) /etc/openshift/express.conf
#   3) $GEM/../conf/express.conf
#
def get_var(var)
  @local_config.get_value(var) ? @local_config.get_value(var) : @global_config.get_value(var)
end

def kfile_not_found
  puts <<KFILE_NOT_FOUND
Your SSH keys are created either by running ssh-keygen (password optional)
or by having the rhc-create-domain command do it for you.  If you created
them on your own (or want to use an existing keypair), be sure to paste
your public key into the dashboard page at http://www.openshift.com.
The client tools use the value of 'rsa_key_file' in express.conf to find
your key.  'libra_id_rsa[.pub]' followed by 'id_rsa[.pub]' are used as
if rsa_key_file isn't specified in express.conf.
Also, make sure you never give out your secret key!
KFILE_NOT_FOUND

exit 212
end

def get_kfile(check_readable=true)
  rsa_key_file_var = get_var('rsa_key_file')
  rsa_key_file = rsa_key_file_var ? rsa_key_file_var : 'libra_id_rsa'
  kfile = "#{ENV['HOME']}/.ssh/#{rsa_key_file}"
  if check_readable && !File.readable?(kfile)
    if rsa_key_file_var
      puts "Unable to read from '#{kfile}' referenced in express.conf."
      kfile_not_found
    else
      kfile = "#{ENV['HOME']}/.ssh/id_rsa"
      if !File.readable?(kfile)
        puts "Unable to read from rsa key file."
        kfile_not_found
      end
    end
  end
  return kfile
end

def get_kpfile(kfile, check_readable=true)
  kpfile = kfile + '.pub'
  if check_readable && !File.readable?(kpfile)
    puts "Unable to read from '#{kpfile}'"
    kfile_not_found
  end
  return kpfile
end