require 'rubygems'
require 'fileutils'
require 'getoptlong'
require 'json'
require 'net/http'
require 'net/https'
#require 'net/ssh'
require 'open3'
require 'parseconfig'
require 'resolv'
require 'uri'

module RHC

  DEFAULT_MAX_LENGTH = 16
  APP_NAME_MAX_LENGTH = 32
  MAX_RETRIES = 7
  DEFAULT_DELAY = 2
  API = "1.1.3"
  PATTERN_VERSION=/\A\d+\.\d+\.\d+\z/
  @mytimeout = 10
  @mydebug = false
  @@api_version = "?.?.?"

  # reset lines
  # \r moves the cursor to the beginning of line
  # ANSI escape code to clear line from cursor to end of line
  # "\e" is an alternative to "\033"
  # cf. http://en.wikipedia.org/wiki/ANSI_escape_code
  CLEAR_LINE = "\r" + "\e[0K"
  
  DEBUG_INGORE_KEYS = {
    'result' => nil,
    'debug' => nil,
    'exit_code' => nil,
    'messages' => nil,
    'data' => nil,
    'api' => nil
  }

  def self.timeout(val)
    if val
      @mytimeout = val.to_i
      unless @mytimeout > 0 
        puts 'Timeout must be specified as a number greater than 0'
        exit 1
      end
    end
  end

  def self.debug(bool)
    @mydebug = bool
  end

  def self.update_server_api_v(dict)
    if !dict['api'].nil? && (dict['api'] =~ PATTERN_VERSION)
      @@api_version = dict['api']
    end
  end

  def self.check_version
    if @@api_version =~ PATTERN_VERSION
      if API != @@api_version
        puts "\nNOTICE: Client API version (#{API}) does not match the server (#{@@api_version}).\nThough requests may succeed, you should consider updating your client tools.\n\n"
      end
    end
  end

  def self.delay(time, adj=DEFAULT_DELAY)
    (time*=adj).to_int
  end

  def self.generate_json(data)
      data['api'] = API
      json = JSON.generate(data)
      json
  end

  def self.get_cartridges_list(libra_server, net_http, cart_type="standalone", print_result=nil)
    puts "Obtaining list of cartridges (please excuse the delay)..."
    data = {'cart_type' => cart_type}
    if @mydebug
      data[:debug] = true
    end
    print_post_data(data)
    json_data = generate_json(data)

    url = URI.parse("https://#{libra_server}/broker/cartlist")
    response = http_post(net_http, url, json_data, "none")

    unless response.code == '200'
      print_response_err(response)
      return []
    end
    begin
      json_resp = JSON.parse(response.body)
    rescue JSON::ParserError
      exit 1
    end
    update_server_api_v(json_resp)
    if print_result
      print_response_success(json_resp)
    end
    begin
      carts = (JSON.parse(json_resp['data']))['carts']
    rescue JSON::ParserError
      exit 1
    end
    carts
  end

  def self.get_cartridge_listing(carts, sep, libra_server, net_http, cart_type="standalone", print_result=nil)
    carts = get_cartridges_list(libra_server, net_http, cart_type, print_result) if carts.nil?
    carts.join(sep)
  end


  # Invalid chars (") ($) (^) (<) (>) (|) (%) (/) (;) (:) (,) (\) (*) (=) (~)
  def self.check_rhlogin(rhlogin)
    if rhlogin
      if rhlogin =~ /["\$\^<>\|%\/;:,\\\*=~]/
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
    check_field(app, 'application', APP_NAME_MAX_LENGTH)
  end

  def self.check_namespace(namespace)
    check_field(namespace, 'namespace', DEFAULT_MAX_LENGTH)
  end

  def self.check_key(keyname)
    check_field(keyname, 'key name', DEFAULT_MAX_LENGTH, /[^0-9_a-zA-Z]/, 
                'contains invalid characters! Only alpha-numeric characters and underscores allowed.')
  end

  def self.check_field(field, type, max=0, val_regex=/[^0-9a-zA-Z]/, 
                       regex_failed_error='contains non-alphanumeric characters!')
    if field
      if field =~ val_regex
        puts "#{type} " + regex_failed_error
        return false
      end
      if max != 0 && field.length > max
        puts "maximum #{type} size is #{max} characters"
        return false
      end
    else
      puts "#{type} is required"
      return false
    end
    true
  end

  def self.print_post_data(h)
    if (@mydebug)
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

  def self.get_user_info(libra_server, rhlogin, password, net_http, print_result, not_found_message=nil)
    data = {'rhlogin' => rhlogin}
    if @mydebug
      data[:debug] = true
    end
    print_post_data(data)
    json_data = generate_json(data)

    url = URI.parse("https://#{libra_server}/broker/userinfo")
    response = http_post(net_http, url, json_data, password)

    unless response.code == '200'
      if response.code == '404'
        if not_found_message
          puts not_found_message
        else
          puts "A user with rhlogin '#{rhlogin}' does not have a registered domain.  Be sure to run 'rhc domain create' before using the other rhc tools."
        end
        exit 99
      elsif response.code == '401'
        puts "Invalid user credentials"
        exit 97
      else
        print_response_err(response)
      end
      exit 1
    end
    begin
      json_resp = JSON.parse(response.body)
    rescue JSON::ParserError
      exit 1
    end
    update_server_api_v(json_resp)
    if print_result
      print_response_success(json_resp)
    end
    begin
      user_info = JSON.parse(json_resp['data'].to_s)
    rescue JSON::ParserError
      exit 1
    end
    user_info
  end

  def self.get_ssh_keys(libra_server, rhlogin, password, net_http)
    data = {'rhlogin' => rhlogin, 'action' => 'list-keys'}
    if @mydebug
      data[:debug] = true
    end
    print_post_data(data)
    json_data = generate_json(data)

    url = URI.parse("https://#{libra_server}/broker/ssh_keys")
    response = http_post(net_http, url, json_data, password)

    unless response.code == '200'
      if response.code == '401'
        puts "Invalid user credentials"
        exit 97
      else
        print_response_err(response)
      end
      exit 1
    end
    begin
      json_resp = JSON.parse(response.body)
    rescue JSON::ParserError
      exit 1
    end
    update_server_api_v(json_resp)
    begin
      ssh_keys = (JSON.parse(json_resp['data'].to_s))
    rescue JSON::ParserError
      exit 1
    end
    ssh_keys
  end

  def self.get_password
    password = nil
    begin
      print "Password: "
      system "stty -echo"
      password = gets.chomp
    rescue Interrupt
      puts "\n"
      exit 1
    ensure
      system "stty echo"
    end
    puts "\n"
    password
  end

  def self.http_post(http, url, json_data, password)
    req = http::Post.new(url.path)

    puts "Contacting #{url.scheme}://#{url.host}" if @mydebug
    req.set_form_data({'json_data' => json_data, 'password' => password})
    http = http.new(url.host, url.port)
    http.open_timeout = @mytimeout
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
      puts "You can use 'rhc domain show' and 'rhc app status' to learn about the status of your user and application(s)."
      exit 219
    end
  end

  def self.print_response_err(response)
    puts "Problem reported from server. Response code was #{response.code}."
    if (!@mydebug)
      puts "Re-run with -d for more information."
    end
    exit_code = 1
    if response.content_type == 'application/json'
      begin
        json_resp = JSON.parse(response.body)
        exit_code = print_json_body(json_resp)
      rescue JSON::ParserError
        exit_code = 1
      end
    elsif @mydebug
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

  def self.print_response_success(json_resp, print_result=false)
    if @mydebug
      print "Response from server:"
      $stdout.flush
      print_json_body(json_resp, print_result)
    elsif print_result
      print_json_body(json_resp)
    else
      print_response_messages(json_resp)
    end
  end

  def self.print_json_body(json_resp, print_result=true)
    print_response_messages(json_resp)
    exit_code = json_resp['exit_code']
    if @mydebug
      if json_resp['debug']
        puts ''
        puts 'DEBUG:'
        puts json_resp['debug']
        puts ''
        puts "Exit Code: #{exit_code}"
        if (json_resp.length > 3)
          json_resp.each do |k,v|
            if !DEBUG_INGORE_KEYS.has_key?(k)
              puts "#{k.to_s}: #{v.to_s}"
            end
          end
        end
      end
      if json_resp['api']
        puts "API version:    #{json_resp['api']}"
      end
    end
    if print_result && json_resp['result']
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
  
  def self.create_app(libra_server, net_http, user_info, app_name, app_type, rhlogin, password, repo_dir=nil, no_dns=false, no_git=false, is_embedded_jenkins=false, gear_size='small',scale=false)
    domains = user_info['user_info']['domains']
    if domains.empty?
      puts "Please create a domain with 'rhc domain create -n <namespace>' before creating applications."
      return false
    end
    namespace = domains[0]['namespace']
    puts "Creating application: #{app_name} in #{namespace}"
    data = {:cartridge => app_type,
            :action => 'configure',
            :node_profile => gear_size,
            :app_name => app_name,
            :rhlogin => rhlogin
           }
    if @mydebug
      data[:debug] = true
    end    

    # Need to use the new REST API for scaling apps
    #  We'll need to then get the new application using the existing
    #  API in order to access the rest of the logic in this function
    if scale
      $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),'..','..','rhc-rest','lib'))
      require 'rhc-rest'
      # Need to have a fake HTTPResponse object for passing to print_reponse_err
      Struct.new('FakeResponse',:body,:code,:content_type)

      #  TODO: This logic should be checked by broker
      unscalable = ['haproxy-1.4','jenkins-1.4','diy-0.1']
      print_response_err(Struct::FakeResponse.new("Can not create a scaling app of type #{app_type}",403)) if unscalable.include?(app_type)

      end_point = "https://#{libra_server}/broker/rest"
      client = Rhc::Rest::Client.new(end_point, rhlogin, password)

      domain = client.find_domain(user_info['user_info']['domains'][0]['namespace']).first
      namespace = domain.namespace
      # Catch errors
      begin
        application = domain.add_application(app_name,app_type,scale)

        # Variables that are needed for the rest of the function
        app_uuid = application.uuid
        result = "Successfully created application: #{app_name}"

        # Since health_check_path is not returned, we need to fudge it for now
        health_check_path =
          case app_type
          when "php-5.3"
            "health_check.php"
          when "perl-5.10"
            "health_check.pl"
          when "diy-0.1", "ruby-1.8", "jenkins-1.4", "python-2.6", "haproxy-1.4", "jbossas-7", "nodejs-0.6"
            "health"
          end

        puts "DEBUG: '#{app_name}' creation returned success." if @mydebug
      rescue Rhc::Rest::ResourceAccessException => e
        print_response_err(Struct::FakeResponse.new(e.message,e.code))
      rescue Rhc::Rest::ValidationException => e
        print_response_err(Struct::FakeResponse.new(e.message,406))
      end
    else
      json_data = generate_json(data)

      url = URI.parse("https://#{libra_server}/broker/cartridge")
      response = http_post(net_http, url, json_data, password)

      if response.code == '200'
        json_resp = JSON.parse(response.body)
        print_response_success(json_resp)
        json_data = JSON.parse(json_resp['data'])
        health_check_path = json_data['health_check_path']
        app_uuid = json_data['uuid']
        result = json_resp['result']
        puts "DEBUG: '#{app_name}' creation returned success." if @mydebug
      else
        print_response_err(response)
      end
    end

    #
    # At this point, we need to register a handler to guarantee app
    # cleanup on any exceptions or calls to exit
    #
    at_exit do
      unless $!.nil? || $!.is_a?(SystemExit) && $!.success?
        puts "Cleaning up application"
        destroy_app(libra_server, net_http, app_name, rhlogin, password)
      end
    end

    rhc_domain = user_info['user_info']['rhc_domain']

    fqdn = "#{app_name}-#{namespace}.#{rhc_domain}"

    loop = 0
    #
    # Confirm that the host exists in DNS
    #
    unless no_dns
      puts "Now your new domain name is being propagated worldwide (this might take a minute)..."
  
      # Allow DNS to propogate
      sleep 15
  
      # Now start checking for DNS
      sleep_time = 2
      while loop < MAX_RETRIES && !hostexist?(fqdn)
          sleep sleep_time
          loop+=1
          print CLEAR_LINE + "    retry # #{loop} - Waiting for DNS: #{fqdn}"
          $stdout.flush
          sleep_time = delay(sleep_time)
      end
    end
    
    # if we have executed print statements, then move to the next line
    if loop > 0
      puts
    end
    
    # construct the Git URL
    git_url = "ssh://#{app_uuid}@#{app_name}-#{namespace}.#{rhc_domain}/~/git/#{app_name}.git/"

    # If the hostname couldn't be resolved, print out the git URL
    # and exit cleanly.  This will help solve issues where DNS times
    # out in APAC, etc on resolution.
    if loop >= MAX_RETRIES
        puts <<WARNING

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
WARNING: We weren't able to lookup your hostname (#{fqdn}) 
in a reasonable amount of time.  This can happen periodically and will just
take an extra minute or two to propagate depending on where you are in the
world.  Once you are able to access your application in a browser, you can then
clone your git repository.

  Application URL: http://#{fqdn}

  Git Repository URL: #{git_url}

  Git Clone command: 
    git clone #{git_url} #{repo_dir}

If you can't get your application '#{app_name}' running in the browser, you can
also try destroying and recreating the application as well using:

  rhc app destroy -a #{app_name} -l #{rhlogin}

If this doesn't work for you, let us know in the forums or in IRC and we'll
make sure to get you up and running.

  Forums: https://www.redhat.com/openshift/forums/express

  IRC: #openshift (on Freenode)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

WARNING
        exit 0
    end
    
    #
    # Pull new repo locally
    #
    
    unless no_git
        puts "Pulling new repo down" if @mydebug
    
        puts "git clone --quiet #{git_url} #{repo_dir}" if @mydebug
        quiet = (@mydebug ? ' ' : '--quiet ')
        git_clone = %x<git clone #{quiet} #{git_url} #{repo_dir}>
        if $?.exitstatus != 0
            puts "Error in git clone"
            puts git_clone
            exit 216
        end
    else
      if is_embedded_jenkins
        # if this is a jenkins client application to be embedded, 
        # then print this message only in debug mode
        if @mydebug
          puts "
Note: There is a git repo for your Jenkins application '#{app_name}'
but it isn't being downloaded as part of this process.  In most cases
it isn't needed but you can always clone it later.

"
        end
      else         
        puts <<IMPORTANT

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
IMPORTANT: Since the -n flag was specified, no local repo has been created.
This means you can't make changes to your published application until after
you clone the repo yourself.  See the git url below for more information.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

IMPORTANT
      end
    end
    
    #
    # At this point, we need to register a handler to guarantee git
    # repo cleanup on any exceptions or calls to exit
    #
    unless no_git
      at_exit do
          unless $!.nil? || $!.is_a?(SystemExit) && $!.success?
              puts "Cleaning up git repo"
              FileUtils.rm_rf repo_dir
          end
      end
    end
    return {:app_name => app_name,
            :fqdn => fqdn,
            :health_check_path => health_check_path,
            :git_url => git_url,
            :repo_dir => repo_dir,
            :result => result
           }
  end

  def self.check_app_available(net_http, app_name, fqdn, health_check_path, result, git_url, repo_dir, no_git)
      #
      # Test several times, doubling sleep time between attempts.
      #
      sleep_time = 2
      attempt = 0
      puts "Confirming application '#{app_name}' is available" if @mydebug
      while attempt < MAX_RETRIES
          attempt += 1
          if @mydebug
            puts "  Attempt # #{attempt}"
          else
            print CLEAR_LINE + "Confirming application '#{app_name}' is available:  Attempt # #{attempt}"
          end
          $stdout.flush
          url = URI.parse("http://#{fqdn}/#{health_check_path}")
          
          sleep(2.0)
          begin
            response = net_http.get_response(url)
          rescue Exception => e
            response = nil
          end
          if !response.nil? && response.code == "200" && response.body[0,1] == "1"
            puts CLEAR_LINE + "Confirming application '#{app_name}' is available:  Success!"
            puts ""
            puts "#{app_name} published:  http://#{fqdn}/"
            puts "git url:  #{git_url}"

            if @mydebug
              unless no_git
                puts "To make changes to '#{app_name}', commit to #{repo_dir}/."
              else
                puts <<LOOKSGOOD
To make changes to '#{app_name}', you must first clone it with:
      git clone #{git_url}

LOOKSGOOD
                puts "Then run 'git push' to update your OpenShift Express space."
              end
            end
            if result && !result.empty?
              puts "#{result}"
            end
            return true
          end
          if !response.nil? && @mydebug
            puts "Server responded with #{response.code}"
            puts response.body unless response.code == '503'
          end
          puts "    sleeping #{sleep_time} seconds" if @mydebug
          sleep sleep_time
          sleep_time = delay(sleep_time)
      end
      return false
  end
  
  def self.destroy_app(libra_server, net_http, app_name, rhlogin, password)
    json_data = generate_json(
                       {:action => 'deconfigure',
                        :app_name => app_name,
                        :rhlogin => rhlogin
                        })
    url = URI.parse("https://#{libra_server}/broker/cartridge")
    http_post(net_http, url, json_data, password)
  end
  
  # Runs rhc-list-ports on server to check available ports
  # :stderr return user-friendly port name, :stdout returns 127.0.0.1:8080 format
  def self.list_ports(rhc_domain, namespace, app_name, app_uuid, debug=true)

    ip_and_port_simple_regex = /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\:[0-9]{1,5}/

    ssh_host = "#{app_name}-#{namespace}.#{rhc_domain}"

    ssh_cmd = "ssh -t #{app_uuid}@#{ssh_host} 'rhc-list-ports'"

    hosts_and_ports = []
    hosts_and_ports_descriptions = []

    puts ssh_cmd if debug

    Open3.popen3(ssh_cmd) { |stdin, stdout, stderr| 

      stdout.each { |line|
        line = line.chomp
        if ip_and_port_simple_regex.match(line)
          hosts_and_ports << line
        end
      }

      stderr.each { |line|
        line = line.chomp

        if line.downcase =~ /permission denied/
          puts line
          exit 1
        end
        
        if line.index(ip_and_port_simple_regex)
          hosts_and_ports_descriptions << line
        end
      }

    }
    
    #hosts_and_ports_descriptions = stderr.gets.chomp.split(/\n/)
    #hosts_and_ports = stdout.gets.chomp.split(/\n/)

    # Net::SSH.start(ssh_host, app_uuid) do |ssh| 

    #   ssh.exec!("rhc-list-ports") do |channel, stream, data|

    #     array = data.split(/\n/)

    #     if stream == :stderr 
    #       hosts_and_ports_descriptions = array
    #     elsif stream == :stdout 
    #       hosts_and_ports = array
    #     end

    #   end

    # end

    return hosts_and_ports, hosts_and_ports_descriptions

  end
  
  def self.ctl_app(libra_server, net_http, app_name, rhlogin, password, action, embedded=false, framework=nil, server_alias=nil, print_result=true)
    data = {:action => action,
            :app_name => app_name,
            :rhlogin => rhlogin
           }
    
    data[:server_alias] = server_alias if server_alias
    if framework
      data[:cartridge] = framework
    end
    
    if @mydebug
      data[:debug] = true
    end
    
    json_data = generate_json(data)

    url = nil
    if embedded
      url = URI.parse("https://#{libra_server}/broker/embed_cartridge")
    else
      url = URI.parse("https://#{libra_server}/broker/cartridge")
    end
    response = http_post(net_http, url, json_data, password)
    
    if response.code == '200'
      json_resp = JSON.parse(response.body)
      print_response_success(json_resp, print_result || @mydebug)
    else
        print_response_err(response)
    end
    JSON.parse(response.body)
  end
end

# provide a hook for performing actions before rhc-* commands exit
at_exit {
  # ensure client tools are up to date
  RHC::check_version
}

#
# Config paths... /etc/openshift/express.conf or $GEM/conf/express.conf -> ~/.openshift/express.conf
#
# semi-private: Just in case we rename again :)
@opts_config_path = nil
@conf_name = 'express.conf'
_linux_cfg = '/etc/openshift/' + @conf_name
_gem_cfg = File.join(File.expand_path(File.dirname(__FILE__) + "/../conf"), @conf_name)
_home_conf = File.expand_path('~/.openshift')
@local_config_path = File.join(_home_conf, @conf_name)
@config_path = File.exists?(_linux_cfg) ? _linux_cfg : _gem_cfg

FileUtils.mkdir_p _home_conf unless File.directory?(_home_conf)
local_config_path = File.expand_path(@local_config_path)
if !File.exists? local_config_path
  file = File.open(local_config_path, 'w')
  begin
    file.puts <<EOF
# SSH key file
#ssh_key_file = 'libra_id_rsa'
EOF

  ensure
    file.close
  end
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
  if ENV['http_proxy']!~/^(\w+):\/\// then
    ENV['http_proxy']="http://" + ENV['http_proxy']
  end
  proxy_uri=URI.parse(ENV['http_proxy'])
  @http = Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
else
  @http = Net::HTTP
end


#
# Support funcs
#
def check_cpath(opts)
  if !opts["config"].nil?
    @opts_config_path = opts["config"]
    if !File.readable?(File.expand_path(@opts_config_path))
      puts "Could not open config file: #{@opts_config_path}"
      exit 253
    else
      begin
        @opts_config = ParseConfig.new(File.expand_path(@opts_config_path))
      rescue Errno::EACCES => e
        puts "Could not open config file (#{@opts_config_path}): #{e.message}"
        exit 253
      end
    end
  end
end

def config_path
  return @opts_config_path ? @opts_config_path : @local_config_path
end

def config
  return @opts_config ? @opts_config : @local_config
end

#
# Check for local var in
#   0) --config path file
#   1) ~/.openshift/express.conf
#   2) /etc/openshift/express.conf
#   3) $GEM/../conf/express.conf
#
def get_var(var)
  v = nil
  if !@opts_config.nil? && @opts_config.get_value(var)
    v = @opts_config.get_value(var)
  else
    v = @local_config.get_value(var) ? @local_config.get_value(var) : @global_config.get_value(var)
  end
  v
end

def kfile_not_found
  puts <<KFILE_NOT_FOUND
Your SSH keys are created either by running ssh-keygen (password optional)
or by having the 'rhc domain create' command do it for you.  If you created
them on your own (or want to use an existing keypair), be sure to paste
your public key into the express console at http://www.openshift.com.
The client tools use the value of 'ssh_key_file' in express.conf to find
your key followed by the defaults of libra_id_rsa[.pub] and then
id_rsa[.pub].
KFILE_NOT_FOUND

#exit 212
end

def get_kfile(check_exists=true)
  ssh_key_file = get_var('ssh_key_file')
  if ssh_key_file
    if (File.basename(ssh_key_file) == ssh_key_file)
      kfile = "#{ENV['HOME']}/.ssh/#{ssh_key_file}"
    else
      kfile = File.expand_path(ssh_key_file)
    end
  else
    kfile = "#{ENV['HOME']}/.ssh/libra_id_rsa"
  end
  if check_exists && !File.exists?(kfile)
    if ssh_key_file
      puts "WARNING: Unable to find '#{kfile}' referenced in express.conf."
      kfile_not_found
    else
      kfile = "#{ENV['HOME']}/.ssh/id_rsa"
      if !File.exists?(kfile)
        puts "WARNING: Unable to find ssh key file."
        kfile_not_found
      end
    end
  end
  return kfile
end

def get_kpfile(kfile, check_exists=true)
  kpfile = kfile + '.pub'
  if check_exists && !File.exists?(kpfile)
    puts "WARNING: Unable to find '#{kpfile}'"
    kfile_not_found
  end
  return kpfile
end

# Add a new namespace to configs
def self.add_rhlogin_config(rhlogin, uuid)
    f = open(File.expand_path(config_path), 'a')
    unless config.get_value('default_rhlogin')
        f.puts("# Default rhlogin to use if none is specified")
        f.puts("default_rhlogin=#{rhlogin}")
        f.puts("")
    end
    f.close
end

# Check / add new host to ~/.ssh/config
def self.add_ssh_config_host(rhc_domain, ssh_key_file_path, ssh_config, ssh_config_d)
  
  puts "Checking ~/.ssh/config"
  ssh_key_file_name = File.basename(ssh_key_file_path)
  if ssh_key_file_path =~ /^#{ENV['HOME']}/
    ssh_key_file_path = ssh_key_file_path[ENV['HOME'].length..-1]
    if ssh_key_file_path =~ /^\// || ssh_key_file_path =~ /^\\/
      ssh_key_file_path = '~' + ssh_key_file_path
    else
      ssh_key_file_path = '~/' + ssh_key_file_path
    end
  end
  if (ssh_key_file_name != 'id_rsa')
    found = false

    begin
        File.open(ssh_config, "r") do |sline|
            while(line = sline.gets)
                if line.to_s.index("Host *.#{rhc_domain}") == 0
                    found = true
                    break
                end
            end
        end
    rescue Errno::EACCES
        puts "Could not read from #{ssh_config}"
        puts "Reason: " + $!
        puts
        puts "Please correct this first.  Then run rerun."
        puts
        exit 213
    rescue Errno::ENOENT
        puts "Could not find #{ssh_config}.  This is ok, continuing"
    end
    if found
        puts "Found #{rhc_domain} in ~/.ssh/config... No need to adjust"
    else
        puts "    Adding #{rhc_domain} to ~/.ssh/config"
        begin
            f = File.open(ssh_config, "a")
            f.puts <<SSH

# Added by 'rhc domain create' on #{`date`}
Host *.#{rhc_domain}
  IdentityFile #{ssh_key_file_path}
  VerifyHostKeyDNS yes
  StrictHostKeyChecking no
  UserKnownHostsFile ~/.ssh/libra_known_hosts

SSH
            f.close
        rescue Errno::EACCES
            puts "Could not write to #{ssh_config}"
            puts "Reason: " + $!
            puts
            puts "Please correct this first.  Then run rerun."
            puts
            exit 214
        rescue Errno::ENOENT
            # Make directory and config if they do not exist
            puts "Could not find directory: " + $!
            puts "creating"
            FileUtils.mkdir_p ssh_config_d
            file = File.open(ssh_config, 'w')
            file.close
            retry
        end
    end

    File.chmod(0700, ssh_config_d)
    File.chmod(0600, ssh_config)
  end
end
