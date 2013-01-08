require 'spec_helper'
require 'rhc/commands'

describe RHC::Auth::Basic do
  let(:user){ 'test_user' }
  let(:password){ 'test pass' }
  let(:auth_hash){ {:user => user, :password => password} }
  let(:options){ (o = Commander::Command::Options.new).default(default_options); o }
  let(:default_options){ {} }

  its(:username){ should be_nil }
  its(:username?){ should be_false }
  its(:password){ should be_nil }
  its(:options){ should be_nil }
  its(:openshift_server){ should == 'openshift.redhat.com' }

  context "with user options" do
    subject{ described_class.new(options) }

    its(:username){ should be_nil }
    its(:username?){ should be_false }
    its(:password){ should be_nil }
    its(:options){ should equal(options) }

    context "that include user info" do
      let(:default_options){ {:rhlogin => user, :password => password} }

      its(:username){ should == user }
      its(:username?){ should be_true }
      its(:password){ should == password }
    end

    context "that includes server" do
      let(:default_options){ {:server => 'test.com'} }

      its(:openshift_server){ should == 'test.com' }
      it do
        subject.should_receive(:ask).with("Login to test.com: ").and_return(user)
        subject.send(:ask_username).should == user
      end
    end
  end

  describe "#ask_username" do
    before{ subject.should_receive(:openshift_server).and_return('test.com') }
    before{ subject.should_receive(:ask).with("Login to test.com: ").and_return(user) }

    it do
      subject.send(:ask_username).should == user
      subject.send(:username).should == user
    end

    context "with a different user" do
      subject{ described_class.new('other', nil) }
      it do
        subject.send(:ask_username).should == user
        subject.send(:username).should == user
      end
    end
  end

  describe "#ask_password" do
    before{ subject.should_receive(:ask).with("Password: ").and_return(password) }
    it do
      subject.send(:ask_password).should == password
      subject.send(:password).should == password
    end

    context "with a different password" do
      subject{ described_class.new(user, 'other') }
      it do
        subject.send(:ask_password).should == password
        subject.send(:password).should == password
      end
    end
  end

  describe "#to_request" do
    let(:request){ {} }

    context "when the request is lazy" do
      let(:request){ {:lazy_auth => true} }
      before{ subject.should_receive(:ask_username).never }
      before{ subject.should_receive(:ask_password).never }

      it { subject.to_request(request).should == request }
    end

    context "when password and user are provided" do
      subject{ described_class.new(user, password) }

      it { subject.to_request(request).should equal(request) }
      it { subject.to_request(request).should == auth_hash }

      context "it should remember cookies" do
        let(:response){ mock(:cookies => [mock(:name => 'rh_sso', :value => '1')], :status => 200) }
        it{ subject.retry_auth?(response); subject.to_request(request)[:cookies].should == {:rh_sso => '1'} }
      end

      context "when the request is lazy" do
        let(:request){ {:lazy_auth => true} }

        it { subject.to_request(request).should == auth_hash.merge(request) }
      end
    end

    context "when initialized with a hash" do
      subject{ described_class.new({:rhlogin => user, :password => password}) }
      its(:username){ should == user }
      its(:password){ should == password }
    end

    context "when password is not provided" do
      subject{ described_class.new(user, nil) }

      its(:password){ should be_nil }
      it "should ask for the password" do
        subject.should_receive(:ask_password).and_return(password)
        subject.to_request(request).should == auth_hash
      end
      it "should remember the password" do
        subject.should_receive(:ask_password).and_return(password)
        subject.to_request(request)
        subject.to_request(request).should == auth_hash
      end

      context "when the request is lazy" do
        let(:request){ {:lazy_auth => true} }
        before{ subject.should_receive(:ask_password).never }

        it { subject.to_request(request).should == auth_hash.merge(request) }
      end
    end

    context "when user is not provided" do
      subject{ described_class.new(nil, password) }

      its(:username){ should be_nil }
      it "should ask for the username" do
        subject.should_receive(:ask_username).and_return(user)
        subject.to_request(request).should == auth_hash
      end
      it "should remember the username" do
        subject.should_receive(:ask_username).and_return(user)
        subject.to_request(request)
        subject.to_request(request).should == auth_hash
      end

      context "when the request is lazy" do
        let(:request){ {:lazy_auth => true} }
        before{ subject.should_receive(:ask_username).never }

        it { subject.to_request(request).should == auth_hash.merge(request) }
      end
    end
  end

  describe "#retry_auth?" do
    context "when the response succeeds" do
      let(:response){ mock(:cookies => {}, :status => 200) }

      it{ subject.retry_auth?(response).should be_false }
      after{ subject.cookie.should be_nil }
    end
    context "when the response succeeds with a cookie" do
      let(:response){ mock(:cookies => [mock(:name => 'rh_sso', :value => '1')], :status => 200) }
      it{ subject.retry_auth?(response).should be_false }
      after{ subject.cookie.should == '1' }
    end
    context "when the response requires authentication" do
      let(:response){ mock(:status => 401) }
      after{ subject.cookie.should be_nil }

      context "with no user and no password" do
        subject{ described_class.new(nil, nil) }
        it("should ask for user and password") do
          subject.should_receive(:ask_username).and_return(user)
          subject.should_receive(:ask_password).and_return(password)
          subject.retry_auth?(response).should be_true
        end
      end

      context "with user and no password" do
        subject{ described_class.new(user, nil) }
        it("should ask for password only") do
          subject.should_receive(:ask_password).and_return(password)
          subject.retry_auth?(response).should be_true
        end
        it("should ask for password twice") do
          subject.should_receive(:ask_password).twice.and_return(password)
          subject.retry_auth?(response).should be_true
          subject.retry_auth?(response).should be_true
        end
      end

      context "with user and password" do
        subject{ described_class.new(user, password) }
        it("should not prompt for reauthentication") do
          subject.should_not_receive(:ask_password)
          subject.should_receive(:error).with("Username or password is not correct")
          subject.retry_auth?(response).should be_false
        end

        it "should forget a saved cookie" do
          subject.instance_variable_set(:@cookie, '1')
          subject.should_not_receive(:ask_password)
          subject.should_receive(:error).with("Username or password is not correct")
          subject.retry_auth?(response).should be_false
        end
      end
    end
  end
end
