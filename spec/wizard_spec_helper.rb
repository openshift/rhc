
module WizardStepsHelper
  def should_greet_user
    next_stage.should_not be_nil

    last_output do |s|
      s.count("\n").should >= 3
      s.should match(/OpenShift Client Tools \(RHC\) Setup Wizard/)
    end
  end

  def should_challenge_for(username, password)
    input_line username.to_s if username
    input_line password.to_s if password
    next_stage.should_not be_nil

    last_output do |s|
      s.send(username ? :should : :should_not, match("Login to "))
      s.send(password ? :should : :should_not, match(/Password: [\*]{8}$/))
    end
  end

  def should_write_config
    test_config_file(false)
  end
  def should_overwrite_config
    test_config_file(true)
  end
  def test_config_file(present)
    File.exists?(current_config_path).should be present

    next_stage.should_not be_nil

    last_output.should match("Creating #{current_config_path} to store your configuration")

    File.readable?(current_config_path).should be true
    RHC::Vendor::ParseConfig.new(current_config_path).tap do |cp|
      cp["default_rhlogin"].should == username
      cp["libra_server"].should == mock_uri
    end
  end

  def should_create_an_ssh_keypair
    setup_mock_ssh
    keys_should_not_exist

    next_stage.should_not be_nil

    keys_should_exist
    last_output.should match('No SSH keys were found. We will generate a pair of keys')
  end

  def should_not_create_an_ssh_keypair
    next_stage.should_not be_nil

    last_output.should == ''
  end

  def should_upload_default_key
    input_line 'yes'

    next_stage.should_not be_nil

    last_output do |s|
      s.should match('Since you do not have any keys associated')
      s.should match(/Fingerprint\: (?:[a-f0-9]{2}\:){15}/)
      s.should match("Uploading key 'default' from #{current_ssh_dir}/id_rsa.pub ... ")
    end
  end

  def should_skip_uploading_key
    input_line 'no'

    next_stage.should_not be_nil

    last_output.should match('You can upload your SSH key at a later time using ')
  end

  def should_find_matching_server_key
    next_stage.should_not be_nil

    last_output.should == ""
  end

  def should_find_git
    setup_mock_has_git(true)

    next_stage.should_not be_nil

    last_output.should match(/Checking for git .*found/)
  end

  def should_display_windows_info
    next_stage.should_not be_nil

    last_output do |s|
      s.should match('Git for Windows')
      s.should match('In order to fully interact with OpenShift you will need to install and configure a git client')
    end
  end

  def should_not_find_git
    setup_mock_has_git(false)

    next_stage.should_not be_nil

    last_output do |s|
      s.should match(/Checking for git .*needs to be installed/)
      s.should match("Automated installation of client tools is not supported for your platform")
    end
  end

  def should_create_a_namespace
    input_line "thisnamespaceistoobigandhastoomanycharacterstobevalid"
    input_line "invalidnamespace" 
    input_line "testnamespace"

    next_stage.should_not be_nil

    last_output do |s|
      s.should match(/Checking your namespace .*none/)
      s.should match(/(?:Too long.*?){2}/m)
    end
  end

  def should_skip_creating_namespace
    input_line ""

    next_stage.should_not be_nil

    last_output do |s|
      s.should match(/Checking your namespace .*none/)
      s.should match("You will not be able to create applications without first creating a namespace")
      s.should match("You may create a namespace later through 'rhc domain create'")
    end
  end

  def should_find_a_namespace(namespace)
    next_stage.should_not be_nil

    last_output.should match(/Checking your namespace .*#{namespace}/)
  end

  def should_list_types_of_apps_to_create
    next_stage.should_not be_nil

    last_output do |s|
      s.should match('rhc app create <app name> mock_standalone_cart-1')
      s.should match('rhc app create <app name> mock_standalone_cart-2')
    end
  end

  def should_find_apps(*args)
    next_stage.should_not be_nil

    last_output do |s|
      s.should match("found #{args.length}")
      args.each do |(name, domain_name)|
        s.should match("#{name} http://#{name}-#{domain_name}.rhcloud.com")
      end
    end
  end

  def should_be_done
    next_stage.should be_true

    last_output.should match("Your client tools are now configured.")
  end
end


module WizardHelper
  def next_stage
    @stages ||= subject.stages
    @stage ||= -1
    @current_stage = @stages[@stage+=1]
    subject.send(@current_stage)
  end

  def current_config_path
    subject.send(:config).config_path
  end

  def setup_mock_has_git(bool)
    subject.stub(:"has_git?") { bool }
  end

  def current_ssh_dir
    subject.send(:config).ssh_dir
  end
  def setup_mock_ssh(add_ssh_key=false)
    FileUtils.mkdir_p current_ssh_dir
    if add_ssh_key
      setup_mock_ssh_keys
    end
  end

  def keys_should_exist
    File.exists?(File.join(current_ssh_dir, "id_rsa")).should be true
    File.exists?(File.join(current_ssh_dir, "id_rsa.pub")).should be true
  end
  def keys_should_not_exist
    File.exists?(File.join(current_ssh_dir, "id_rsa")).should be false
    File.exists?(File.join(current_ssh_dir, "id_rsa.pub")).should be false
  end

  def priv_key
    <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIICWwIBAAKBgQDIXpBBs7g93z/5JqW5IJNJR8bG6DWhpL2vR2ROEfzGqDHLZ+Xb
saS/Ogc3nZNSav3juHWdiBFIc0unPpLdwmXtcL3tjN52CJqPgU/W0q061fL/tk77
fFqW2upluo0ZRZQdPc3vTI3tWWZcpyE2LPHHUOI3KN+lRqxgw0Y6z/3SfwIDAQAB
AoGAbMC+xZp5TsPEokOywWeH6cdWgZF5wpF7Dw7Nx34F2AFkfYWYAgVKaSxizHHv
i1VdFmOBGw7Gaq+BiXXyGwEvdpmgDoZDwvJrShZef5LwYnJ/NCqjZ8Xbb9z4VxCL
pkqMFFpEeNQcIDLZRF8Z1prRQnOL+Z498P6d3G/UWkR5NXkCQQDsGlpJzJwAPpwr
YZ98LgKT0n2WHeCrMQ9ZyJQl3Dz40qasQmIotB+mdIh87EFex7vvyiuzRC5rfcoX
CBHEkQpVAkEA2UFNBKgI1v5+16K0/CXPakQ25AlGODDv2VXlHwRPOayUG/Tn2joj
fj0T4/pu9AGhz0oVXFlz7iO8PEwFU+plgwJAKD2tmdp31ErXj0VKS34EDnHX2dgp
zMPF3AWlynYpJjexFLcTx+A7bMF76d7SnXbpf0sz+4/pYYTFBvvnG1ulKQJACJsR
lfGiCAIkvB3x1VsaEDeLhRTo9yjZF17TqJrfGIXBiCn3VSmgZku9EfbFllzKMA/b
MMFKWlCIEEtimqRaSQJAPVA1E7AiEvfUv0kRT73tDf4p/BRJ7p2YwjxrGpDBQhG1
YI+4NOhWtAG3Uips++8RhvmLjv8y+TNKU31J1EJmYA==
-----END RSA PRIVATE KEY-----
EOF
  end

  def pub_key
    <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDIXpBBs7g93z/5JqW5IJNJR8bG6DWhpL2vR2ROEfzGqDHLZ+XbsaS/Ogc3nZNSav3juHWdiBFIc0unPpLdwmXtcL3tjN52CJqPgU/W0q061fL/tk77fFqW2upluo0ZRZQdPc3vTI3tWWZcpyE2LPHHUOI3KN+lRqxgw0Y6z/3Sfw== OpenShift-Key
EOF
  end

  def rsa_key_content_public
    'AAAAB3NzaC1yc2EAAAADAQABAAABAQDJ54a/MlApilkfv7VCQS3lyUL5tHkJbuKNHOk6BtREsdrATZOpB3En3bRlgDMeGR0tAuRanvBai8TQG2kZluwdqAuTER0hiuZrAimrUHWbkQGZlwGWHBzNw/98gliZJYkZchAJjyzdQULbzq9xhcXzfYhUbZH1SGq6sThmR63tiYZHlbqQ+a56vpyFQsVEzvq5uqkvcJpSX74gDo0xqAAxSdNYZTBpLgFMB9Xzk/1UNlZ9C1SNDxEwFQZgzNriVyrGsJWaXfZdJRBa0PwScPEpJ4VlDFEgdtynjE1LabUAdMBoBXlr8QZgNHCuc3hUq/IVm3NShx+J3hVO3mP8HcLJ'
  end
  def rsa_key_fingerprint_public
    '18:2a:99:6c:9b:65:6f:a5:13:57:c9:41:c7:b4:24:36'
  end

  class Sshkey < OpenStruct
    def type
      @table[:type]
    end
    def type=(type)
      @table[:type] = type
    end
  end

  def mock_key_objects
    [
      Sshkey.new(:name => 'default',  :type => 'ssh-rsa', :fingerprint => "0f:97:4b:82:87:bb:c6:dc:40:a3:c1:bc:bb:55:1e:fa"),
      Sshkey.new(:name => 'cb490595', :type => 'ssh-rsa', :fingerprint => "cb:49:05:95:b4:42:1c:95:74:f7:2d:41:0d:f0:37:3b"),
      Sshkey.new(:name => '96d90241', :type => 'ssh-rsa', :fingerprint => "96:d9:02:41:e1:cb:0d:ce:e5:3b:fc:da:13:65:3e:32"),
      Sshkey.new(:name => '73ce2cc1', :type => 'ssh-rsa', :fingerprint => "73:ce:2c:c1:01:ea:79:cc:f6:be:86:45:67:96:7f:e3")
    ]
  end

  def setup_mock_ssh_keys(dir=current_ssh_dir)
    private_key_file = File.join(dir, "id_rsa")
    public_key_file = File.join(dir, "id_rsa.pub")
    File.open(private_key_file, 'w') { |f| f.write priv_key }

    File.open(public_key_file, 'w') { |f| f.write pub_key }
  end

  def setup_different_config
    path = File.join(File.join(home_dir, '.openshift'), 'express.conf')
    FileUtils.mkdir_p File.dirname(path)
    File.open(path, "w") do |file|
      file.puts <<EOF
# Default user login
default_rhlogin='a_different_user'

# Server API
libra_server = 'a_different_server.com'
EOF
    end
    path
  end
end

Spec::Runner.configure do |config|
  config.include(WizardHelper)
  config.include(WizardStepsHelper)
end
