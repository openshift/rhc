require 'spec_helper'
require 'rest_spec_helper'
require 'base64'

module RHC
  module Rest
    describe Application do
      let (:client) { RHC::Rest::Client.new('test.domain.com', 'test_user', 'test pass') }
      let (:app_links) { mock_response_links(mock_app_links('mock_domain','mock_app')) }
      let (:app_aliases) { ['alias1','alias2'] }
      let (:app_obj) {
        args = {
          'domain_id'       => 'mock_domain',
          'name'            => 'mock_app',
          'creation_time'   => Time.now.to_s,
          'uuid'            => 1234,
          'aliases'         => app_aliases,
          'server_identity' => mock_uri,
          'links'           => app_links
        }
        args.merge!(attributes) if defined?(attributes)
        RHC::Rest::Application.new(args, client)
      }
      context "#new" do
        it "returns an application object" do
          app = app_obj
          app.should be_an_instance_of RHC::Rest::Application
          app.send(:links).length.should equal(app_links.length)
        end
      end

      describe "#ssh_string" do
        context "with valid url" do
          subject{ described_class.new('ssh_url' => "ssh://foo@bar.com/path") }
          its(:ssh_string){ should == "foo@bar.com" }
        end
        context "with bad url" do
          subject{ described_class.new('ssh_url' => "ssh://") }
          its(:ssh_string){ should == "ssh://" }
        end
      end

      describe "#host" do
        context "with bad url" do
          subject{ described_class.new('app_url' => "http://") }
          its(:app_url){ should == "http://" }
          its(:host){ should be_nil }
        end
        context "with http url" do
          subject{ described_class.new('app_url' => "http://bar.com/path") }
          its(:app_url){ should == "http://bar.com/path" }
          its(:host){ should == "bar.com" }
        end
      end

      context "#add_cartridge" do
        context "with a name" do
          before{ stub_api_request(:any, app_links['ADD_CARTRIDGE']['relative'], false).with(:body => {:name => 'mock_cart_0'}.to_json).to_return(mock_cartridge_response) }
          it "accepts a string" do
            cart = app_obj.add_cartridge('mock_cart_0')
            cart.should be_an_instance_of RHC::Rest::Cartridge
            cart.name.should == 'mock_cart_0'
          end
          it "accepts an object" do
            cart = app_obj.add_cartridge(double(:name => 'mock_cart_0', :url => nil))
            cart.should be_an_instance_of RHC::Rest::Cartridge
            cart.name.should == 'mock_cart_0'
          end
          it "accepts a hash" do
            cart = app_obj.add_cartridge(:name => 'mock_cart_0')
            cart.should be_an_instance_of RHC::Rest::Cartridge
            cart.name.should == 'mock_cart_0'
          end
        end

        context "with a URL cart" do
          before{ stub_api_request(:any, app_links['ADD_CARTRIDGE']['relative'], false).with(:body => {:url => 'http://foo.com'}.to_json).to_return(mock_cartridge_response(1, true)) }
          it "raises without a param" do
            app_obj.should_receive(:has_param?).with('ADD_CARTRIDGE','url').and_return(false)
            expect{ app_obj.add_cartridge({:url => 'http://foo.com'}) }.to raise_error(RHC::Rest::DownloadingCartridgesNotSupported)
          end
          it "accepts a hash" do
            app_obj.should_receive(:has_param?).with('ADD_CARTRIDGE','url').and_return(true)
            cart = app_obj.add_cartridge({:url => 'http://foo.com'})
            cart.should be_an_instance_of RHC::Rest::Cartridge
            cart.name.should == 'mock_cart_0'
            cart.url.should == 'http://a.url/0'
            cart.short_name.should == 'mock_cart_0'
            cart.display_name.should == 'mock_cart_0'
            cart.only_in_new?.should be_true
            cart.only_in_existing?.should be_false
          end
          it "accepts an object" do
            app_obj.should_receive(:has_param?).with('ADD_CARTRIDGE','url').and_return(true)
            cart = app_obj.add_cartridge(double(:url => 'http://foo.com'))
            cart.should be_an_instance_of RHC::Rest::Cartridge
            cart.name.should == 'mock_cart_0'
            cart.url.should == 'http://a.url/0'
            cart.short_name.should == 'mock_cart_0'
            cart.display_name.should == 'mock_cart_0'
            cart.only_in_new?.should be_true
            cart.only_in_existing?.should be_false
          end
        end
      end

      context "#aliases" do
        context "when the server returns an array of strings" do
          it{ app_obj.aliases.first.should be_an_instance_of RHC::Rest::Alias }
          it("converts to an object"){ app_obj.aliases.map(&:id).should == app_aliases }
        end

        context "when the server returns an object" do
          let(:app_aliases){ [{'id' => 'alias1'}, {'id' => 'alias2'}] }
          it{ app_obj.aliases.first.should be_an_instance_of RHC::Rest::Alias }
          it{ app_obj.aliases.map(&:id).should == ['alias1', 'alias2'] }
        end

        context "when the server doesn't return aliases" do
          let(:app_aliases){ nil }
          context "when the client supports LIST_ALIASES" do
            before{ stub_api_request(:any, app_links['LIST_ALIASES']['relative'], false).to_return(mock_alias_response(2)) }
            it{ app_obj.aliases.first.should be_an_instance_of RHC::Rest::Alias }
            it{ app_obj.aliases.map(&:id).should == ['www.alias0.com', 'www.alias1.com'] }
          end
          context "when the client doesn't support LIST_ALIASES" do
            before{ app_links['LIST_ALIASES'] = nil }
            it{ app_obj.aliases.should == [] }
          end
        end
      end

      context "#cartridges" do
        let(:num_carts){ 0 }
        before do
          stub_api_request(:any, app_links['LIST_CARTRIDGES']['relative'], false).
            to_return(mock_cartridge_response(num_carts))
        end
        context "with carts" do
          let(:num_carts){ 2 }
          it "returns a list of all cartridges in the current application" do
            app   = app_obj
            carts = app.cartridges
            carts.length.should == 2
            (0..1).each do |idx|
              carts[idx].should be_an_instance_of RHC::Rest::Cartridge
              carts[idx].name.should == "mock_cart_#{idx}"
            end
          end
        end
        context "without carts" do
          it "returns an empty list" do
            app   = app_obj
            carts = app.cartridges
            carts.length.should == 0
          end
        end
        context "with carts included in initial reponse" do
          let(:attributes){ {:cartridges => RHC::Json.decode(mock_cartridge_response(2)[:body])['data'] }}
          it "returns a list of all cartridges in the current application" do
            app   = app_obj
            carts = app.cartridges
            carts.length.should == 2
            (0..1).each do |idx|
              carts[idx].should be_an_instance_of RHC::Rest::Cartridge
              carts[idx].name.should == "mock_cart_#{idx}"
            end
          end
        end
      end

      context "#gear_groups" do
        before do
          stub_api_request(:any, app_links['GET_GEAR_GROUPS']['relative'], false).
            to_return(mock_gear_groups_response())
        end
        it "returns a list of all gear groups the current application" do
          app   = app_obj
          gear_groups = app.gear_groups
          gear_groups.length.should equal(1)
          gear_groups[0].should be_an_instance_of RHC::Rest::GearGroup
        end
      end

      # These application control tests are subtle; the key lies in making sure the
      # webmock specifies the expected body that is sent in the request.
      # This is currently of the form "event=foo"
      shared_examples_for "a control method" do
        before do
          @control_method = control_data[:method]
          @control_call   = [@control_method]
          if control_data.has_key?(:arg)
            @control_call << control_data[:arg]
          end
          @control_event  = control_data.has_key?(:event)   ? control_data[:event]       : @control_method.to_s
          @control_link   = control_data.has_key?(:link)    ? control_data[:link].upcase : @control_method.to_s.upcase
          @control_output = control_data.has_key?(:result)  ? control_data[:result]      : @control_event
          @with_payload   = control_data.has_key?(:payload) ? control_data[:payload]     : true
          if @with_payload
            stub_api_request(:any, app_links[@control_link]['relative'], false).
              with(:body => { 'event' => @control_event }). # This is the critical part
              to_return({ :body => { :data => @control_event }.to_json, :status => 200 })
          else
            stub_api_request(:any, app_links[@control_link]['relative'], false).
              to_return({ :body => { :data => @control_event }.to_json, :status => 200 })
          end
        end
        it "sends the control request to the server" do
          app = app_obj
          expect { app.send(*@control_call)  }.to_not raise_error
          app.send(*@control_call).should == @control_output
        end
      end

      context "#start" do
        let(:control_data) { { :method => :start } }
        it_should_behave_like "a control method"
      end

      context "#stop" do
        context " and the request is not forced (force == false)" do
          let(:control_data) { { :method => :stop } }
          it_should_behave_like "a control method"
        end
        context " and the request is forced (force == true)" do
          let(:control_data) { { :method => :stop, :arg => true, :event => 'force-stop', :link => 'stop' } }
          it_should_behave_like "a control method"
        end
      end

      context "#restart" do
        let(:control_data) { { :method => :restart } }
        it_should_behave_like "a control method"
      end

      context "#delete" do
        let(:control_data) { { :method => :delete, :payload => false } }
        it_should_behave_like "a control method"
      end

      context "#destroy" do
        let(:control_data) { { :method => :destroy, :event => 'delete', :link => 'delete', :payload => false } }
        it_should_behave_like "a control method"
      end

      context "#scale_up" do
        let(:control_data) { { :method => :scale_up, :event => 'scale-up', :link => 'scale_up', :payload => false } }
        it_should_behave_like "a control method"
      end

      context "#scale_down" do
        let(:control_data) { { :method => :scale_down, :event => 'scale-down', :link => 'scale_down', :payload => false } }
        it_should_behave_like "a control method"
      end
    end
  end
end

