require 'spec_helper'
require 'direct_execution_helper'

describe "rhc sshkey scenarios" do
  context "with an existing domain" do
    before(:all) do
      standard_config
      @domain = has_a_domain
    end

    let(:domain){ @domain }

    context "with an application" do
      before{ has_an_application }

      it "should add and remove kerberos keys on gear" do
        app = @domain.applications.first
        keyname = "key#{rand(1000000000000)}"
        keycontent = "principal#{rand(1000000000000)}"
        
        r = rhc 'sshkey', 'add', keyname, '--type', 'krb5-principal', '--content', keycontent
        r.status.should == 0

        r = rhc 'ssh', app.name, '-n', domain.name, '--ssh', ssh_exec_for_env, '--', 'if [ -f .k5login ]; then cat .k5login; fi'
        r.status.should == 0
        r.stdout.should match(Regexp.new("#{keyname}\n#{keycontent}"))

        r = rhc 'sshkey', 'remove', keyname
        r.status.should == 0

        r = rhc 'ssh', app.name, '-n', domain.name, '--ssh', ssh_exec_for_env, '--', 'if [ -f .k5login ]; then cat .k5login; fi'
        r.status.should == 0
        r.stdout.should_not match(Regexp.new("#{keyname}\n#{keycontent}"))
      end
    end
  end
end
