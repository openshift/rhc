require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/sshkey'
require 'rhc/config'


describe RHC::Commands::Sshkey do
  let!(:rest_client){ MockRestClient.new }
  before{ user_config }

  describe 'list' do

    context "when run with list command" do
      let(:arguments) { %w[sshkey list --noprompt --config test.conf -l test@test.foo -p  password --trace] }

      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match(/mockkey1 \(type: ssh-rsa\)/) }
    end
  end

  describe 'show' do
    context "when run with show command" do
      let(:arguments) { %w[sshkey show mockkey1 --noprompt --config test.conf -l test@test.foo -p  password --trace] }

      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match(/mockkey1 \(type: ssh-rsa\)/) }
    end
  end

  describe "add" do
    context "when adding a valid key" do
      let(:arguments) { %w[sshkey add --noprompt --config test.conf -l test@test.foo -p password foobar id_rsa.pub] }

      it 'adds the key' do
        FakeFS do
          keys = rest_client.sshkeys
          num_keys = keys.length
          File.open('id_rsa.pub', 'w') do |f|
            f << 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnCOqK7/mmvZ9AtCAerxjAasJ1rSpfuWT4vNm1+O/Fh0Di3chTWjY9a0M2hEnqkqnVG589L9CqCUeT0kdc3Vgw3JEcacSUr1z7tLr9kO+p/D5lSdQYzDGGRFOZ0H6lc/y8iNxWV1VO/sJvKx6cr5zvKIn8Q6GvhVNOxlai0IOb9FJxLGK95GLpZ+elzh8Tc9giy7KfwheAwhV2JoF9uRltE5JP/CNs7w/E29i1Z+jlueuu8RVotLmhSVNJm91Ey7OCtoI1iBE0Wv/SucFe32Qi08RWTM/MaGGz93KQNOVRGjNkosJjPmP1qU6WGBfliDkJAZXB0b6sEcnx1fbVikwZ'
          end
          expect { run }.to exit_with_code(0)
          rest_client.sshkeys.length.should == num_keys + 1
        end
      end
    end

    context "when adding an invalid key" do
      let(:arguments) { %w[sshkey add --noprompt --config test.conf -l test@test.foo -p password foobar id_rsa.pub] }

      it "fails to add the key" do
        FakeFS do
          keys = rest_client.sshkeys
          num_keys = keys.length
          File.open('id_rsa.pub', 'w') do |f|
            f << 'ssh-rsa AADAQABAAABAQCnCOqK7/mmvZ9AtCAerxjAasJ1rSpfuWT4vNm1+O/Fh0Di3chTWjY9a0M2hEnqkqnVG589L9CqCUeT0kdc3Vgw3JEcacSUr1z7tLr9kO+p/D5lSdQYzDGGRFOZ0H6lc/y8iNxWV1VO/sJvKx6cr5zvKIn8Q6GvhVNOxlai0IOb9FJxLGK95GLpZ+elzh8Tc9giy7KfwheAwhV2JoF9uRltE5JP/CNs7w/E29i1Z+jlueuu8RVotLmhSVNJm91Ey7OCtoI1iBE0Wv/SucFe32Qi08RWTM/MaGGz93KQNOVRGjNkosJjPmP1qU6WGBfliDkJAZXB0b6sEcnx1fbVikwZ'
          end
          expect { run }.to exit_with_code(128)
          expect { run_output.should match(/Name:.* mockkey/) }
          rest_client.sshkeys.length.should == num_keys
        end
      end

      it "does not throw an error on an empty file" do
        FakeFS do
          keys = rest_client.sshkeys
          num_keys = keys.length
          File.open('id_rsa.pub', 'w') do |f|
            f << ''
          end
          expect { run }.to exit_with_code(128)
          expect { run_output.should match(/Name:.* mockkey/) }
          rest_client.sshkeys.length.should == num_keys
        end
      end

      it "exits with status code Errno::EACCES::Errno" do
        IO.should_receive(:read).and_return("ssh_foo bar")
        expect { run }.to exit_with_code(128)
      end
    end

    context "when adding an invalid key with --confirm" do
      let(:arguments) { %w[sshkey add --noprompt --confirm --config test.conf -l test@test.foo -p password foobar id_rsa.pub] }

      it "warns and then adds the key" do
        FakeFS do
          keys = rest_client.sshkeys
          num_keys = keys.length
          File.open('id_rsa.pub', 'w') do |f|
            f << 'ssh-rsa AADAQABAAABAQCnCOqK7/mmvZ9AtCAerxjAasJ1rSpfuWT4vNm1+O/Fh0Di3chTWjY9a0M2hEnqkqnVG589L9CqCUeT0kdc3Vgw3JEcacSUr1z7tLr9kO+p/D5lSdQYzDGGRFOZ0H6lc/y8iNxWV1VO/sJvKx6cr5zvKIn8Q6GvhVNOxlai0IOb9FJxLGK95GLpZ+elzh8Tc9giy7KfwheAwhV2JoF9uRltE5JP/CNs7w/E29i1Z+jlueuu8RVotLmhSVNJm91Ey7OCtoI1iBE0Wv/SucFe32Qi08RWTM/MaGGz93KQNOVRGjNkosJjPmP1qU6WGBfliDkJAZXB0b6sEcnx1fbVikwZ'
          end
          expect { run }.to exit_with_code(0)
          expect { run_output.should match("key you are uploading is not recognized") }
          rest_client.sshkeys.length.should == num_keys + 1
        end
      end
    end

    context "when adding a nonexistent key" do
      let(:arguments) { %w[sshkey add --noprompt --config test.conf -l test@test.foo -p password foobar id_rsa.pub] }
    
      it "exits with status code Errno::ENOENT::Errno" do
        expect { run }.to exit_with_code(128)
      end
    end
    
    context "when attempting to add an existing but inaccessible key" do
      let(:arguments) { %w[sshkey add --noprompt --config test.conf -l test@test.foo -p password foobar inaccessible_key.pub] }
      
      #before :all do
      #  @inaccessible_key = 'inaccessible_key.pub'
      #  File.new(@inaccessible_key, 'w+')
      #  File.chmod(0000, @inaccessible_key)
      #end
      
      #after :all do
      #  File.delete @inaccessible_key
      #end
    
      it "exits with status code Errno::EACCES::Errno" do
        IO.should_receive(:read).and_raise(Errno::EACCES)
        expect { run }.to exit_with_code(128)
      end

    end
  end

  describe "remove" do
    context "when removing an existing key" do
      let (:arguments) { %w[sshkey remove --noprompt --config test.conf -l test@test.foo -p password mockkey2] }

      it 'deletes the key' do
        keys = rest_client.sshkeys
        num_keys = keys.length
        expect{ run }.to exit_with_code(0)
        rest_client.sshkeys.length.should == num_keys - 1
      end
    end

    context "when removing a nonexistent key" do
      let (:arguments) { %w[sshkey remove --noprompt --config test.conf -l test@test.foo -p password no_match] }
      before{ @keys = rest_client.sshkeys }

      it 'leaves keys untouched' do
        num_keys = @keys.length
        expect{ run }.to exit_with_code(0)
        rest_client.sshkeys.length.should == num_keys
      end
    end
  end
end
