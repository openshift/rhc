require 'rubygems' # Will eventually be removed when this file is deprecated
require 'fileutils'
require 'getoptlong'
require 'net/http'
require 'net/https'
require 'net/ssh'
require 'rhc/vendor/sshkey'
require 'resolv'
require 'uri'
require 'highline/import'
require 'rhc'
require 'rhc/rest'
require 'rhc/helpers'
require 'rhc/config'
require 'rhc/wizard'
require 'rhc/targz'
require 'rhc/json'

module RHC

  DEFAULT_MAX_LENGTH = 16
  APP_NAME_MAX_LENGTH = 32
  MAX_RETRIES = 7
  DEFAULT_DELAY = 2.0
  API = "1.1.3"
  PATTERN_VERSION=/\A\d+\.\d+\.\d+\z/
  @read_timeout = 120
  @connect_timeout = 20
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

  def self.timeout(*vals)
    vals.each do |val|
      if val
        unless val.to_i > 0
          puts 'Timeout must be specified as a number greater than 0'
          exit 1
        end
        @read_timeout = [val.to_i, @read_timeout].max
        return @read_timeout
      end
    end
  end

  def self.connect_timeout(*vals)
    vals.each do |val|
      if val
        unless val.to_i > 0
          puts 'Timeout must be specified as a number greater than 0'
          exit 1
        end
        @connect_timeout = [val.to_i, @connect_timeout].max
        return @connect_timeout
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
  
  def self.json_encode(data)
    RHC::Json.encode(data)
  end

  def self.json_decode(json)
    RHC::Json.decode(json)
  end

  def self.generate_json(data)
      data['api'] = API
      json = json_encode(data)
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
      json_resp = json_decode(response.body)
    rescue RHC::JsonError
      exit 1
    end
    update_server_api_v(json_resp)
    if print_result
      print_response_success(json_resp)
    end
    begin
      carts = (json_decode(json_resp['data']))['carts']
    rescue RHC::JsonError
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
        puts 'OpenShift login may not contain any of these characters: (\") ($) (^) (<) (>) (|) (%) (/) (;) (:) (,) (\) (*) (=) (~)'
        return false
      end
    else
      puts "OpenShift login is required"
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
    check_field(keyname, 'key name', DEFAULT_MAX_LENGTH, /[^0-9a-zA-Z]/, 
                'contains invalid characters! Only alpha-numeric characters allowed.')
  end

  def self.check_field(field, type, max=0, val_regex=/[^0-9a-zA-Z]/, 
                       regex_failed_error='contains non-alphanumeric characters!')
    if field
      if field =~ val_regex
        say "#{type} " + regex_failed_error
        return false
      end
      if max != 0 && field.length > max
        say "maximum #{type} size is #{max} characters"
        return false
      end
    else
      say "#{type} is required"
      return false
    end
    field
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
      json_resp = json_decode(response.body)
    rescue RHC::JsonError
      exit 1
    end
    update_server_api_v(json_resp)
    if print_result
      print_response_success(json_resp)
    end
    begin
      user_info = json_decode(json_resp['data'].to_s)
    rescue RHC::JsonError
      exit 1
    end
    user_info
  end

  # Public: Get a list of ssh keys
  #
  # type - The String type RSA or DSS.
  # libra_server - The String DNS for the broker
  # rhlogin - The String login name
  # password - The String password for login
  # net_http - The NET::HTTP Object to use
  #
  # Examples
  #
  #  RHC::get_ssh_keys('openshift.redhat.com',
  #                    'mylogin@example.com',
  #                    'mypassword',
  #                    RHC::Config.default_proxy)
  #  # => { "ssh_type" => "ssh-rsa",
  #         "ssh_key" => "AAAAB3NzaC1yc2EAAAADAQAB....",
  #         "fingerprint" => "ea:08:e3:c7:e3:c3:8e:6a:66:34:65:e4:56:f4:3e:ff"}
  #
  # FIXME!  Exits on failure!  Should return something instead
  #
  # Returns Hash on success or exits on failure
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
      json_resp = json_decode(response.body)
    rescue RHC::JsonError
      exit 1
    end
    update_server_api_v(json_resp)
    begin
      ssh_keys = (json_decode(json_resp['data'].to_s))
    rescue RHC::JsonError
      exit 1
    end

    # Inject public fingerprint into key.
    begin
      if ssh_keys['ssh_type'].nil? or ssh_keys['ssh_type'].empty?
        ssh_keys['fingerprint'] = nil
      else
        ssh_keys['fingerprint'] = \
          Net::SSH::KeyFactory.load_data_public_key(
            "#{ssh_keys['ssh_type']} #{ssh_keys['ssh_key']}").fingerprint
      end
    rescue NoMethodError 
      #older net/ssh (mac for example)
      tempfile = `mktemp /tmp/openshift.XXXXXXXX`
      `echo "#{ssh_keys['ssh_type']} #{ssh_keys['ssh_key']}" > #{tempfile}`
      ssh_keys['fingerprint'] = `ssh-keygen -lf #{tempfile}`.split(' ')[1]
    rescue Net::SSH::Exception, NotImplementedError, OpenSSL::PKey::PKeyError
      # Could be a new unsupported key type or invalid data on the server
      ssh_keys['fingerprint'] = 'Key type is not recognized.  Please check this key is valid.'
    end

    if ssh_keys['keys'] && ssh_keys['keys'].kind_of?(Hash)
      ssh_keys['keys'].each do |name, keyval|
        type = keyval['type']
        key = keyval['key']
        begin
          ssh_keys['keys'][name]['fingerprint'] = \
            Net::SSH::KeyFactory.load_data_public_key(
              "#{type} #{key}").fingerprint
        rescue NoMethodError
          #older net/ssh (mac for example)
          tempfile = `mktemp /tmp/openshift.XXXXXXXX`
          `echo "#{type} #{key}" > #{tempfile}`
          ssh_keys['keys'][name]['fingerprint'] = `ssh-keygen -lf #{tempfile}`.split(' ')[1]
        rescue NotImplementedError, Net::SSH::Exception, OpenSSL::PKey::PKeyError
          # Could be a new unsupported key type or invalid data on the server
          ssh_keys['keys'][name]['fingerprint'] = 'Key type is not recognized.  Please check this key is valid.'
        end
      end
    end
    ssh_keys
  end

  def self.get_password
    password = nil
    begin
      password = ask_password
    rescue Interrupt
      puts "\n"
      exit 1
    end
    puts "\n"
    password
  end

  def self.http_post(http, url, json_data, password)
    req = http::Post.new(url.path)

    puts "Contacting #{url.scheme}://#{url.host}" if @mydebug
    req.set_form_data({'json_data' => json_data, 'password' => password})
    req['User-Agent'] = RHC::Helpers.user_agent

    http = http.new(url.host, url.port)
    http.open_timeout = @connect_timeout
    http.read_timeout = @read_timeout
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
    if response.class.inspect == "Struct::FakeResponse"
      print_response_message(response.body)
    elsif response.content_type == 'application/json'
      begin
        json_resp = json_decode(response.body)
        exit_code = print_json_body(json_resp)
      rescue RHC::JsonError
        exit_code = 1
      end
    elsif @mydebug
      puts "HTTP response from server is #{response.body}"
    end
    exit exit_code.nil? ? 666 : exit_code
  end

  def self.print_response_messages(json_resp)
    messages = json_resp['messages']
    print_response_message(messages)
  end

  def self.print_response_message(message)
    if (message && !message.empty?)
      puts ''
      puts 'MESSAGES:'
      puts message
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

    # Need to have a fake HTTPResponse object for passing to print_reponse_err
    # May already be initialized if called from another piece of code
    # FIXME: remove this requirement when refactoring rhc
    begin
      Struct::FakeResponse
    rescue NameError
      Struct.new('FakeResponse',:body,:code,:content_type)
    end

    domains = user_info['user_info']['domains']
    if domains.empty?
      emessage = "Please create a domain with 'rhc domain create -n <namespace>' before creating applications."
      print_response_err(Struct::FakeResponse.new(emessage,403))
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
      end_point = "https://#{libra_server}/broker/rest/api"
      client = RHC::Rest::Client.new(end_point, rhlogin, password)

      domain = client.find_domain(user_info['user_info']['domains'][0]['namespace'])

      namespace = domain.id
      # Catch errors
      begin
        application = domain.add_application(app_name,{:cartridge => app_type, :scale => true, :gear_profile => gear_size})

        # Variables that are needed for the rest of the function
        app_uuid = application.uuid
        result = "Successfully created application: #{app_name}"

        # health check path now returned by the API
        health_check_path = application.health_check_path

        puts "DEBUG: '#{app_name}' creation returned success." if @mydebug
      rescue RHC::Rest::ConnectionException, RHC::Rest::ResourceAccessException => e
        print_response_err(Struct::FakeResponse.new(e.message,e.code))
      rescue RHC::Rest::ValidationException => e
        validation_error_code = (e.code.nil?) ? 406 : e.code
        print_response_err(Struct::FakeResponse.new(e.message, validation_error_code))
      rescue RHC::Rest::ServerErrorException => e
        error_code = (e.code.nil?) ? 500 : e.code
        print_response_err(Struct::FakeResponse.new(e.message, error_code))
      end
    else
      json_data = generate_json(data)

      url = URI.parse("https://#{libra_server}/broker/cartridge")
      response = http_post(net_http, url, json_data, password)

      if response.code == '200'
        json_resp = json_decode(response.body)
        print_response_success(json_resp)
        json_data = json_decode(json_resp['data'])
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
WARNING: We were unable to lookup your hostname (#{fqdn}) 
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

  Forums: https://openshift.redhat.com/community/forums/openshift

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
    
        quiet = (@mydebug ? ' ' : '--quiet ')
        puts "git clone #{quiet}#{git_url} #{repo_dir}" if @mydebug
        git_clone = %x[git clone #{quiet} #{git_url} #{repo_dir} 2>&1]
        if $?.exitstatus != 0

          if RHC::Helpers.windows? 

            `nslookup #{app_name}-#{namespace}.#{rhc_domain}`
            windows_nslookup = $?.exitstatus == 0
            `ping #{app_name}-#{namespace}.#{rhc_domain} -n 2`
            windows_ping = $?.exitstatus == 0
            
            if windows_nslookup and !windows_ping # this is related to BZ #826769
              puts <<WINSOCKISSUE

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
WARNING: We were unable to lookup your hostname (#{fqdn}) 
in a reasonable amount of time.  This can happen periodically and will just
take up to 10 extra minutes to propagate depending on where you are in the
world. This may also be related to an issue with Winsock on Windows [1][2]. 
We recommend you wait a few minutes then clone your git repository manually.

  Git Clone command: 
    git clone #{git_url} #{repo_dir}

[1] http://support.microsoft.com/kb/299357
[2] http://support.microsoft.com/kb/811259

If this doesn't work for you, let us know in the forums or in IRC and we'll
make sure to get you up and running.

  Forums: https://openshift.redhat.com/community/forums/openshift

  IRC: #openshift (on Freenode)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

WINSOCKISSUE
              exit 0
            end
          end
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

  #
  # An application is considered available if the health check URL unambiguously returns a 1 or 0.
  # Otherwise, if the root URL for the app successfully returns content it is also considered
  # successful.  In the future, applications that do not expose a public web interface will need
  # a more advanced check mechanism, or the check should not prevent creation.
  #
  def self.check_app_available(net_http, app_name, fqdn, health_check_path, result, git_url, repo_dir, no_git)

    available = MAX_RETRIES.times.any? do |i|
      sleep i * DEFAULT_DELAY

      puts "Checking if the application is available ##{i+1}"
      if health_check_path and !health_check_path.empty?
        value = open("http://#{fqdn}/#{health_check_path}").read[0,1] rescue nil
        # TODO: I should be typed exception ApplicationHealthFailure
        raise "ERROR: The application was unable to start.  Please report this issue via the forums or IRC or file a bug through our public bug tracker." if value == '0'
        next true if value == '1'
      end
      open("http://#{fqdn}") rescue nil
    end

    if available
      puts "Application #{app_name} is available at: http://#{fqdn}/"
      puts "  Git URL: #{git_url}"

      if @mydebug
        unless no_git
          puts "To make changes to '#{app_name}', commit to #{repo_dir}/."
        else
          puts <<LOOKSGOOD
To make changes to '#{app_name}', you must first clone it with:
git clone #{git_url}

LOOKSGOOD
          puts "Then run 'git push' to update your OpenShift space."
        end
      end
      if result && !result.empty?
        puts "#{result}"
      end
      true
    else
      puts "Application is not available"
      false
    end
  rescue StandardError => e
    puts e
    false
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
      json_resp = json_decode(response.body)
      print_response_success(json_resp, print_result || @mydebug)
    else
        print_response_err(response)
    end
    json_decode(response.body)
  end

  def self.snapshot_create(rhc_domain, namespace, app_name, app_uuid, filename, debug=false)

    ssh_cmd = "ssh #{app_uuid}@#{app_name}-#{namespace}.#{rhc_domain} 'snapshot' > #{filename}"
    puts "Pulling down a snapshot to #{filename}..."
    puts ssh_cmd if debug
    puts 

    begin

      if ! RHC::Helpers.windows?
        output = `#{ssh_cmd}`
        if $?.exitstatus != 0
          puts output
          puts "Error in trying to save snapshot.  You can try to save manually by running:"
          puts
          puts ssh_cmd
          puts
          return 1
        end
      else
        Net::SSH.start("#{app_name}-#{namespace}.#{rhc_domain}", app_uuid) do |ssh|
          File.open(filename, 'wb') do |file|
            ssh.exec! "snapshot" do |channel, stream, data|
              if stream == :stdout
                file.write(data)
              else
                puts data if debug
              end
            end
          end
        end
      end
    rescue Exception => e
      puts e.backtrace if debug
      puts "Error in trying to save snapshot.  You can try to save manually by running:"
      puts
      puts ssh_cmd
      puts
      return 1
    end
    true
  end

  def self.snapshot_restore(rhc_domain, namespace, app_name, app_uuid, filename, debug=false)
    if File.exists? filename

      if ! RHC::Helpers.windows? and ! RHC::TarGz.contains filename, './*/' + app_name

        puts "Archive at #{filename} does not contain the target application: ./*/#{app_name}"
        puts "If you created this archive rather than exported with rhc-snapshot, be sure"
        puts "the directory structure inside the archive starts with ./<app_uuid>/"
        puts "i.e.: tar -czvf <app_name>.tar.gz ./<app_uuid>/"
        return 255

      else

        include_git = RHC::Helpers.windows? ? false : RHC::TarGz.contains(filename, './*/git')

        ssh_cmd = "cat #{filename} | ssh #{app_uuid}@#{app_name}-#{namespace}.#{rhc_domain} 'restore#{include_git ? ' INCLUDE_GIT' : ''}'"
        puts "Restoring from snapshot #{filename}..."
        puts ssh_cmd if debug
        puts 

        begin
          if ! RHC::Helpers.windows?
            output = `#{ssh_cmd}`
            if $?.exitstatus != 0
              puts output
              puts "Error in trying to restore snapshot.  You can try to restore manually by running:"
              puts
              puts ssh_cmd
              puts
              return 1
            end
          else
            ssh = Net::SSH.start("#{app_name}-#{namespace}.#{rhc_domain}", app_uuid)
            ssh.open_channel do |channel|
              channel.exec("restore#{include_git ? ' INCLUDE_GIT' : ''}") do |ch, success|
                channel.on_data do |ch, data|
                  puts data
                end
                channel.on_extended_data do |ch, type, data|
                  puts data
                end
                channel.on_close do |ch|
                  puts "Terminating..."
                end
                File.open(filename, 'rb') do |file|
                  file.chunk(1024) do |chunk|
                    channel.send_data chunk
                  end
                end
                channel.eof!
              end
            end
            ssh.loop
          end
        rescue Exception => e
          puts e.backtrace
          puts "Error in trying to restore snapshot.  You can try to restore manually by running:"
          puts
          puts ssh_cmd
          puts
          return 1
        end

      end
    else
      puts "Archive not found: #{filename}"
      return 255
    end
    true
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
@home_conf = File.expand_path('~/.openshift')
@local_config_path = File.join(@home_conf, @conf_name)
@config_path = File.exists?(_linux_cfg) ? _linux_cfg : _gem_cfg
@home_dir=File.expand_path("~")

local_config_path = File.expand_path(@local_config_path)

#
# Check for proxy environment
#

@http = RHC::Config.default_proxy

def config_path
  return @opts_config_path ? @opts_config_path : @local_config_path
end

def config
  return @opts_config ? @opts_config : @local_config
end

def ask_password
  return ask("Password: ") { |q| q.echo = '*' }
end

def kfile_not_found
  puts <<KFILE_NOT_FOUND
Your SSH keys are created either by running ssh-keygen (password optional)
or by having the 'rhc domain create' command do it for you.  If you created
them on your own (or want to use an existing keypair), be sure to paste
your public key into the express console at http://www.openshift.com.
The client tools use the value of 'ssh_key_file' in express.conf to find
your key followed by the defaults of id_rsa[.pub] and then
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
    kfile = "#{ENV['HOME']}/.ssh/id_rsa"
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
    config_path = RHC::Config.local_config_path
    f = open(File.expand_path(config_path), 'a')
    unless RHC::Config['default_rhlogin']
        f.puts("# Default rhlogin to use if none is specified")
        f.puts("default_rhlogin=#{rhlogin}")
        f.puts("")
    end
    f.close
end

# Public: Handle response message when updating keys
#
# url - The Object URI::HTTPS
# data - The Hash representation of the data response
# password - The String password for the user
#
# Examples
#
#  handle_key_mgmt_response(
#                  URI.parse('https://openshift.redhat.com/broker/ssh_keys'),
#                  {
#                    :rhlogin=>"rhnlogin@example.com",
#                    :key_name=>"default",
#                    :action=>"update-key",
#                    :ssh=>"AAAAB3NzaC1yc2EAAAADAQABAAAAgQCrXG5c.....",
#                    :key_type=>"ssh-rsa"},
#                  'mypass')
#  # => nil
#
# Returns nil on Success and RHC::http object on failure
def handle_key_mgmt_response(url, data, password)
  RHC::print_post_data(data)
  json_data = RHC::generate_json(data)

  response = RHC::http_post(RHC::Config.default_proxy, url, json_data, password)

  if response.code == '200'
    begin
      json_resp = RHC::json_decode(response.body)
      RHC::update_server_api_v(json_resp)
      RHC::print_response_success(json_resp)
      puts "Success"
      return
    rescue RHC::JsonError
      RHC::print_response_err(response)
    end
  else
    RHC::print_response_err(response)
  end
  puts "Failure"
  return response
end

# Public: Add or upload an ssh key
#
# type - The String type RSA or DSS.
# command - The String value 'add' or 'update'
# identifier - The String value to identify the key
# pub_key_file_path - The String file path of the public key
# rhlogin - The String login to the broker
# password- The String password for the user
#
# Examples
#
#  generate_ssh_key_ruby('add', 'newkeyname', '~/.ssh/id_rsa',
#                        'mylogin', 'mypass')
#  # => /home/user/.ssh/id_rsa.pub
#
# Returns nil on success or HTTP object on failure
def add_or_update_key(command, identifier, pub_key_file_path, rhlogin, password)

  # Read user public ssh key
  if pub_key_file_path
    if File.readable?(pub_key_file_path)
      begin
        ssh_keyfile_contents = File.open(pub_key_file_path).gets.chomp.split(' ')
        ssh_key = ssh_keyfile_contents[1]
        ssh_key_type = ssh_keyfile_contents[0]
      rescue Exception => e
        puts "Invalid public keyfile format! Please specify a valid user public keyfile."
        exit 1
      end
    else
      puts "Unable to read user public keyfile #{pub_key_file_path}"
      exit 1
    end
  else # create key
    key_name = identifier
    puts "Generating ssh key pair for user '#{key_name}' in the dir '#{Dir.pwd}/'"
    # REMOVED in favor of generate_ssh_key_ruby: system("ssh-keygen -t rsa -f '#{key_name}'")
    ssh_pub_key_file = generate_ssh_key_ruby()
    ssh_keyfile_contents = File.open(ssh_pub_key_file).gets.chomp.split(' ')
    ssh_key = ssh_keyfile_contents[1]
    ssh_key_type = ssh_keyfile_contents[0]
  end

  data = {}
  data[:rhlogin] = rhlogin
  data[:key_name] = identifier
  data[:ssh] = ssh_key
  data[:action] = 'add-key'
  data[:key_type] = ssh_key_type

  if command == 'add'
    data[:action] = 'add-key'
  elsif command == 'update'
    data[:action] = 'update-key'
  end

  url = URI.parse("https://#{RHC::Config['libra_server']}/broker/ssh_keys")
  handle_key_mgmt_response(url, data, password)
end


# Public: Generate an SSH key and store it in ~/.ssh/id_rsa
#
# type - The String type RSA or DSS.
# bits - The Integer value for number of bits.
# comment - The String comment for the key
#
# Examples
#
#  generate_ssh_key_ruby()
#  # => /home/user/.ssh/id_rsa.pub
#
# Returns nil on failure or public key location as a String on success
def generate_ssh_key_ruby(type="RSA", bits = 1024, comment = "OpenShift-Key")
  key = RHC::Vendor::SSHKey.generate(:type => type,
                                     :bits => bits,
                                     :comment => comment)
  ssh_dir = "#{RHC::Config.home_dir}/.ssh"
  if File.exists?("#{ssh_dir}/id_rsa")
    puts "SSH key already exists: #{ssh_dir}/id_rsa.  Reusing..."
    return nil
  else
    unless File.exists?(ssh_dir)
      FileUtils.mkdir_p(ssh_dir)
      File.chmod(0700, ssh_dir)
    end
    File.open("#{ssh_dir}/id_rsa", 'w') {|f| f.write(key.private_key)}
    File.chmod(0600, "#{ssh_dir}/id_rsa")
    File.open("#{ssh_dir}/id_rsa.pub", 'w') {|f| f.write(key.ssh_public_key)}
  end
  "#{ssh_dir}/id_rsa.pub"
end

# Public: Run ssh command on remote host
#
# host - The String of the remote hostname to ssh to.
# username - The String username of the remote user to ssh as.
# command - The String command to run on the remote host.
#
# Examples
#
#  ssh_ruby('myapp-t.rhcloud.com',
#            '109745632b514e9590aa802ec015b074',
#            'rhcsh tail -f $OPENSHIFT_LOG_DIR/*"')
#  # => true
#
# Returns true on success
def ssh_ruby(host, username, command)
  Net::SSH.start(host, username) do |session|
    session.open_channel do |channel|
      channel.request_pty do |ch, success|
        puts "pty could not be obtained" unless success
      end

      channel.on_data do |ch, data|
        #puts "[#{file}] -> #{data}"
        puts data
      end
      channel.exec command
    end
    session.loop
  end
end

# Public: legacy convinience function for getting config keys
def get_var(key)
  RHC::Config[key]
end
