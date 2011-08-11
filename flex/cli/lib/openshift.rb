#!/usr/bin/env ruby
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
require 'net/http/post/multipart'
require 'parseconfig'
require 'resolv'
require 'uri'
require 'highline/import'
require 'cgi'

@libra_kfile = "#{ENV['HOME']}/.ssh/libra_id_rsa"
@libra_kpfile = "#{ENV['HOME']}/.ssh/libra_id_rsa.pub"
@conf_name = 'openshift.conf'

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
    puts "openshift.conf contains user configuration and can be transferred across clients."
    puts ""
end

begin
    $global_config = ParseConfig.new(@config_path)
    $local_config = ParseConfig.new(File.expand_path(@local_config_path))
rescue Errno::EACCES => e
    puts "Could not open config file: #{e.message}"
    exit 253
end

# Check for proxy environment
if ENV['http_proxy']
    host, port = ENV['http_proxy'].split(':')
    @http = Net::HTTP::Proxy(host, port)
else
    @http = Net::HTTP
end

def conf(name)
    val = $local_config.get_value(name) ? $local_config.get_value(name) : $global_config.get_value(name)
    val.gsub!(/\\:/,":") if not val.nil?
    #print "CONF #{name} => #{val}\n\n"
    val
end

def setconf(name,value)
    $local_config.add(name,value)
    $local_config.write(File.open(File.expand_path(@local_config_path),"w"))
end

HighLine.track_eof=false
HighLine.color_scheme = HighLine::ColorScheme.new do |cs|
    cs[:emphasis]       = [ :blue, :bold ]      
    cs[:error]          = [ :red ]
    cs[:warn]           = [ :red ]    
    cs[:debug]          = [ :red, :on_white, :bold ]        
    cs[:conf]           = [ :green ]    
    cs[:question]       = [ :magenta, :bold ]
    cs[:table]          = [ :blue ]  
    cs[:table_header]   = [ :bold ]      
    cs[:message]        = [ :bold ]
end

@h = HighLine.new
def csay(str,*options)
    lastChar = str[-1..-1]
    h = HighLine.new    
    if lastChar == ' ' or lastChar == '\t'
        str=h.color(str[0..-2],*options)+lastChar
    else
        str=h.color(str,*options)
    end
    h.say(str)
end

def debug(*s)
    @h = HighLine.new if @h.nil?
    if @debug or conf('debug') == "true"
        str = "DEBUG"
        str += " "*(@h.output_cols()-str.length) if str.length < @h.output_cols()
        csay(str,:debug)
        s.each{ |line|
            str = line.to_s
            str += " "*(@h.output_cols()-str.length) + "\n" if str.length < @h.output_cols()
            csay(str,:debug)
        }
    end
end

module Openshift
    module SSH
        def self.gen_ssh_keys(libra_kfile, libra_kpfile)
            if File.readable?(libra_kfile)
                puts "OpenShift ssh key found at #{libra_kfile}.  Reusing..."
            else
                puts "Generating OpenShift ssh key to #{libra_kfile}"
                # Use system for interaction
                system("ssh-keygen -t rsa -f '#{libra_kfile}'")
            end
            ssh_key = File.open(libra_kpfile).gets.chomp.split(' ')[1]
        end
        
        def self.setup_ssh_config(domain)
            ssh_config = "#{ENV['HOME']}/.ssh/config"
            ssh_config_d = "#{ENV['HOME']}/.ssh/"
            # Check / add new host to ~/.ssh/config
            puts "Checking ~/.ssh/config"

            found = false
            begin
                File.open(ssh_config, "r") do |sline|
                    while(line = sline.gets)
                        if line.to_s.start_with? "Host *.#{domain}"
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
                puts "Found #{domain} in ~/.ssh/config... No need to adjust"
            else
                puts "    Adding #{domain} to ~/.ssh/config"
                begin
                    f = File.open(ssh_config, "a")
                    f.puts <<SSH

            # Added by rhc-create-application on #{`date`}
            Host *.#{domain}
                IdentityFile ~/.ssh/libra_id_rsa
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
    
    module Validation
        Maxdlen = 16
        
        TYPES = {
            'php-5.3' => :php,
            'perl-5.10' => :perl,
            'rack-1.1' => :rack,
            'wsgi-3.2' => :wsgi,
            'jbossas-7.0' => :jbossas
          }

        EXPRESS_SUPPORTED_TYPES = {
            'php-5.3' => :php,
            'rack-1.1' => :rack,
            'wsgi-3.2' => :wsgi
        }
        
        def self.get_supportted_templates(sep=', ', target="express")
            if target == "express"
                return get_cartridge_types(EXPRESS_SUPPORTED_TYPES)
            else
                return get_cartridge_types(FLEX_SUPPORTED_TYPES)
            end
        end
        
        def self.check_login(login)
            if login
                if login.length < 6
                    csay('Login must be at least 6 characters\n',:error)
                    return false
                elsif login =~ /["\$\^<>\|%\/;:,\\\*=~]/
                    csay('Login may not contain any of these characters: (\") ($) (^) (<) (>) (|) (%) (/) (;) (:) (,) (\) (*) (=) (~)\n',:error)
                    return false
                end
            else
                csay("Login is required\n",:error)
                return false
            end
            true
        end
        
        def self.check_field(field, type, max=0, space_ok=false)
            if field
                if space_ok 
                    if field =~ /[^0-9a-zA-Z ]/
                        csay("#{type} contains non-alphanumeric characters!\n",:error)
                        return false
                    end
                else 
                    if field =~ /[^0-9a-zA-Z]/
                        csay("#{type} contains non-alphanumeric characters!\n",:error)
                        return false
                    end
                end
                if max != 0 && field.length > max
                    csay("maximum #{type} size is #{max} characters\n",:error)
                    return false
                end
                if field.strip.length == 0
                    csay("#{type} is required",:error)
                    return false                    
                end
            else
                csay("#{type} is required",:error)
                return false
            end
            true
        end
    end
    
    module IO
        def self.prompt(prompt, options=nil,func=nil,required=false,echo=true,limit=nil)
            input = nil
            while input == nil
                if options.nil? or options.length == 0
                    csay("#{prompt}? ",:question)
                    input = ask(""){ |q|
                        q.echo = "*" if !echo
                        q.limit = limit if !limit.nil?
                    }
                else
                    csay("#{prompt} [#{options.join(',')}]? default: ",:question)
                    input = ask(""){ |q|
                        q.default = options[0] if !options.nil? and options.length > 0                        
                    }
                    if options.index(input).nil?
                        csay("Invalid value: #{input}. Please choose from ",:error)
                        csay("[#{options.join(',')}]",:emphasis)
                        input = nil
                    end
                end
                
                if func and not func.call(input)
                    input = nil
                end
                
                if required and (input.nil? or input.strip == "")
                    csay("This is required field. Please enter a value.",:error)
                    input = nil
                end
            end
            input
        end
    end
    
    module Formatter
        def self.table( col_names, col_keys, col_sizes, rows, indent=0)
            self.print_row_delim(col_sizes,indent)
            print (" " * 4 * indent)
            csay("| ",:table)
            (0...col_names.size).each{ |i|
                csay(sprintf("%#{col_sizes[i]}s ",col_names[i]),:table_header)
                csay("| ",:table)
            }
            print "\n"
            self.print_row_delim(col_sizes,indent)
            rows.each{ |r|
                print (" " * 4 * indent)
                csay("| ",:table)
                (0...col_names.size).each{ |i|
                    if not r[col_keys[i]].nil?
                        printf "%#{col_sizes[i]}s ", r[col_keys[i]]
                    else
                        printf "%#{col_sizes[i]}s ", "   "
                    end
                    csay("| ", :table)                                   
                }
                print "\n"
            }
            self.print_row_delim(col_sizes,indent)
        end
        
        def self.print_row_delim(col_sizes,indent)
            print(" " * 4 * indent)            
            str = "+"
            col_sizes.each{ |s|
                str += "-"*(s+2)
                str += "+"
            }
            csay(str,:table)
        end
    end
    
    module Rest
        def self.execute(http, req, url, params=nil, cookies=nil, auth=nil)
            cookies ||= ''
          
            req['cookie']=""
            cookies.each{ |cookie|
                req['cookie'] += cookie
            }
            
            debug "---cookie---"
            debug req['cookie']
            debug "------------"

            req.set_form_data(params) if params
            req.basic_auth(auth['user'], auth['password']) if auth != nil

            http = http.new(url.host, url.port)
            #http.set_debug_output $stderr
            if url.scheme == "https"
                http.use_ssl = true
                http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                http.timeout = 60*10               
            end
            http.open_timeout = 10
            http.read_timeout = 60*10
            begin
                response = http.start {|http| http.request(req)}
                response.each{|k,v|
                    debug "Header: #{k}:#{v}"
                }
                debug "Response code:#{response.code} body:#{response.body}"
                response
            rescue Exception => e
                return e
            end
        end

        def self.doHttp(http, method, url, params=nil, cookies=nil, auth=nil)
            case method
            when "POST"
                post(http, url, params, cookies, auth)
            when "PUT"
                put(http, url, params, cookies, auth)
            when "GET"
                get(http, url, params, cookies, auth)
            when "DELETE"
                delete(http, url, params, cookies, auth)
            else
                get(http, url, params, cookies, auth)
            end
        end

        def self.put(http, url, params=nil, cookies=nil, auth=nil)
            req = http::Put.new(url.path)
            execute(http, req, url, params, cookies, auth)
        end

        def self.get(http, url, params=nil, cookies='', auth=nil)
            path = url.path
            path += "?" + params.collect { |k,v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&') if not params.nil?
            req = http::Get.new(path)
            execute(http, req, url, nil, cookies, auth)
        end

        def self.postFile(http, url, params, fileParam, cookies=nil, auth=nil)
            paramName=fileParam.keys[0]            
            fileName=fileParam[paramName]
            response=nil
            File.open(fileName) do |file|
                params[paramName] = UploadIO.new(file, "application/octet-stream", File.basename(fileName))
                req = Net::HTTP::Post::Multipart.new(url.path, params)
                response = execute(http, req, url, nil, cookies, auth)
            end
            response
        end

        def self.post(http, url, params, cookies=nil, auth=nil)
            req = http::Post.new(url.path)            
            execute(http, req, url, params, cookies, auth)
        end

        def self.delete(http, url, params, cookies=nil, auth=nil)
            req = http::Delete.new(url.path)
            execute(http, req, url, params, cookies, auth)
        end
    end
    
    def self.login(http, username, password)
        login_server = conf('login_server')
        login_url = URI.parse("#{login_server}/wapps/streamline/login.html")
        response = Rest.post(http, login_url, {'login' => username, 'password' => password})
        case response
            when Net::HTTPUnauthorized:
                csay("Invalid username or password.\n", :red, :bold)
                exit -1
        end
        debug response
        response['Set-Cookie'].split("\; ")[0] + "\; "
    end
        
    def self.add_rhlogin_config(rhlogin, uuid=nil)
        f = open(File.expand_path(@local_config_path), 'a')
        
        unless @local_config.get_value('username')
            f.puts("# Default rhlogin to use if none is specified") 
            f.puts("username=#{rhlogin}")
        end
        f.puts("#{rhlogin}=#{uuid}") unless @local_config.get_value('uuid') or uuid.nil?
        f.close
    end
    
    module Flex
        TEMPLATES = {
            'php' => ['php-5', 'www-dynamic'],                                                                                                                                                                                          
            'zend' => ['zend-server-php', 'www-dynamic'],                                                                                                                                                                               
            'zend_ce' => ['zend-server-ce', 'www-dynamic'],                                                                                                                                                                             
            'tomcat' => ['tomcat', 'jdk6'],                                                                                                                                                                                             
            'jboss6' => ['jboss-6', 'jdk6'],
            'jboss7' => ['jboss-7', 'jdk6']
        }
        
        def self.templates
            return TEMPLATES
        end
    end
    
    module Git
        def self.git_repo?
            `git rev-parse --show-toplevel 2> /dev/null`.strip != ""
        end
        
        def self.get_git_base_dir
            `git rev-parse --show-toplevel 2> /dev/null`.strip
        end
        
        def self.add_remote(uri,remote_name)
            system("git remote add #{remote_name} #{uri}")
        end
        
        def self.clone(uri,dirName,remote_name="origin")
            system("git clone #{uri} #{dirName} --origin #{remote_name} --quiet")
        end
        
        def self.pull(remote_name="origin")
            system("git pull #{remote_name} master --quiet")
        end
        
        def self.push(uri,remote_name)
            system("git push #{remote_name} master --quiet")
        end
    end
    
    module Debug
        def self.print_post_data(h)
            debug 'DEBUG: Submitting form:'
            h.each do |k,v|
                if k.to_s != 'password'
                    debug "#{k.to_s}: #{v.to_s}"
                else
                    debug 'password: ' + ("X" * v.length)
                end
            end
        end
    end
    
    module Express
        Maxdlen = 16
        Maxretries = 10
        Defaultdelay = 2
        
        def self.delay(time, adj=Defaultdelay)
            (time*=adj).to_int
        end

        def self.get_cartridges_list(libra_server, net_http, cart_type="standalone", debug=true, print_result=nil)
            puts "Contacting https://#{libra_server} to obtain list of cartridges..."
            puts " (please excuse the delay)"
            data = {'cart_type' => cart_type}
            if debug
                data['debug'] = "true"
            end
            print_post_data(data, debug)
            json_data = JSON.generate(data)

            url = URI.parse("https://#{libra_server}/broker/cartlist")
            response = http_post(net_http, url, json_data, "none")

            unless response.code == '200'
                print_response_err(response, debug)
                return []
            end
            json_resp = JSON.parse(response.body)
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

        def self.print_response_err(response)
            puts "Problem reported from server. Response code was #{response.code}."
            exit_code = 254
            if response.content_type == 'application/json'
                exit_code = print_json_body(response, debug)
            elsif debug
                debug "HTTP response from server is #{response.body}"
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

        def self.print_response_success(response, debug, always_print_result=false)
            if debug
                puts "Response from server:"
                print_json_body(response, debug)
            elsif always_print_result
                print_json_body(response, debug)
            else
                json_resp = JSON.parse(response.body)
                print_response_messages(json_resp)
            end
        end

        def self.print_json_body(response, debug)
            json_resp = JSON.parse(response.body)
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
                            if (k != 'result' && k != 'debug' && k != 'exit_code' && k != 'messages')
                                puts "#{k.to_s}: #{v.to_s}"
                            end
                        end
                    end
                end
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
end
