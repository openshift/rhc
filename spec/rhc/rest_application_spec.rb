require 'spec_helper'
require 'rest_spec_helper'
require 'rhc-rest/client'

Spec::Runner.configure do |configuration|
  include(RestSpecHelper)
end

module Rhc
  module Rest
    describe Application do
      let (:app_links) { mock_response_links(mock_app_links('mock_domain','mock_app')) }
      let (:app_obj) {
        Rhc::Rest::Application.new({ 'domain_id'       => 'mock_domain',
                                     'name'            => 'mock_app',
                                     'creation_time'   => Time.now.to_s,
                                     'uuid'            => 1234,
                                     'aliases'         => ['alias1','alias2'],
                                     'server_identity' => mock_uri,
                                     'links'           => app_links
                                   })
      }
      context "#new" do
        it "returns an application object" do
          app = app_obj
          app.should be_an_instance_of Rhc::Rest::Application
          app.instance_variable_get(:@links).length.should equal(app_links.length)
        end
      end

      context "#add_cartridge" do
        before do
          stub_request(:any, mock_href(app_links['ADD_CARTRIDGE']['relative'], true)).
            to_return(mock_cartridge_response)
        end
        it "returns a new cartridge object" do
          app  = app_obj
          cart = app.add_cartridge('mock_cart_0')
          cart.should be_an_instance_of Rhc::Rest::Cartridge
          cart.instance_variable_get(:@name).should == 'mock_cart_0'
        end
      end

      context "#cartridges" do
        before(:each) do
          stub_request(:any, mock_href(app_links['LIST_CARTRIDGES']['relative'], true)).
            to_return(mock_cartridge_response(2)).
            to_return(mock_cartridge_response(0))
        end
        it "returns a list of all cartridges in the current application" do
          app   = app_obj
          carts = app.cartridges
          carts.length.should equal(2)
          (0..1).each do |idx|
            carts[idx].should be_an_instance_of Rhc::Rest::Cartridge
            carts[idx].instance_variable_get(:@name).should == "mock_cart_#{idx}"
          end
        end
        it "returns an empty list if the current app has no cartridges" do
          app   = app_obj
          carts = app.cartridges # Disregard the first request;
          carts = app.cartridges # 2nd request simulates empty response.
          carts.length.should equal(0)
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
            stub_request(:any, mock_href(app_links[@control_link]['relative'], true)).
              with(:body => { 'event' => @control_event }). # This is the critical part
              to_return({ :body => { :data => @control_event }.to_json, :status => 200 })
          else
            stub_request(:any, mock_href(app_links[@control_link]['relative'], true)).
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
    end
  end
end

