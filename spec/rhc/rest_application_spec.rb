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
      let (:cart_links) { mock_response_links(mock_app_links('mock_domain','mock_app')) }
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
          app.class.should equal(Rhc::Rest::Application)
          app.instance_variable_get(:@links).length.should equal(app_links.length)
        end
      end

      context "#add_cartridge" do
        before do
          stub_request(:any, mock_href(app_links['ADD_CARTRIDGE']['relative'], true)).
              to_return({ :body   => {
                            :type => 'cartridge',
                            :data => {
                              :name  => 'mock_cart',
                              :type  => 'mock_cart_type',
                              :links => mock_response_links(mock_cart_links('mock_domain','mock_app','mock_cart'))
                             }
                          }.to_json,
                          :status => 200
                        })
        end
        it "returns a new cartridge object" do
          app  = app_obj
          cart = app.add_cartridge('mock_cart')
          cart.class.should equal(Rhc::Rest::Cartridge)
          cart.instance_variable_get(:@name).should == 'mock_cart'
        end
      end

      context "#cartridges" do
        before do
          stub_request(:any, mock_href(app_links['LIST_CARTRIDGES']['relative'], true)).
            to_return({ :body   => {
                          :type => 'cartridges',
                          :data => [{ :name  => 'mock_cart_0',
                                      :type  => 'mock_cart_0_type',
                                      :links => mock_response_links(mock_cart_links('mock_domain','mock_app','mock_cart_0'))
                                    },
                                    { :name  => 'mock_cart_1',
                                      :type  => 'mock_cart_1_type',
                                      :links => mock_response_links(mock_cart_links('mock_domain','mock_app','mock_cart_1'))
                                    }]
                        }.to_json,
                        :status => 200
                      }).
            to_return({ :body   => {
                          :type => 'cartridges',
                          :data => []
                        }.to_json,
                        :status => 200
                      })            
        end
        it "returns a list of all cartridges in the current application" do
          app   = app_obj
          carts = app.cartridges
          carts.length.should equal(2)
          (0..1).each do |idx|
            carts[idx].class.should equal(Rhc::Rest::Cartridge)
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
        it "sends the control request to the server" do
          app = app_obj
          expect { eval 'app.' + control_method.to_s }.to_not raise_error
          eval( 'app.' + control_method.to_s ).should == control_method.to_s
        end
      end

      context "#start" do
        let(:control_method) { :start }
        before do
          stub_request(:any, mock_href(app_links['START']['relative'], true)).
            with(:body => { 'event' => 'start' }). # This is the critical part
            to_return({ :body => { :data => 'start' }.to_json, :status => 200 })
        end
        it_should_behave_like "a control method"
      end

      context "#stop" do
        context " and the request is not forced (force == false)" do
          let(:control_method) { :stop }
          before do
            stub_request(:any, mock_href(app_links['STOP']['relative'], true)).
              with(:body => { 'event' => 'stop' }). # This is the critical part
              to_return({ :body => { :data => 'stop' }.to_json, :status => 200 })
          end
          it_should_behave_like "a control method"
        end
        context " and the request is forced (force == true)" do
          before do
            stub_request(:any, mock_href(app_links['STOP']['relative'], true)).
              with(:body => { 'event' => 'force-stop' }). # This is the critical part
              to_return({ :body => { :data => 'force-stop' }.to_json, :status => 200 })
          end
          it "should request a forced stop" do
            app = app_obj
            expect { app.stop(true) }.to_not raise_error
            app.stop(true).should == 'force-stop'
          end
        end
      end

      context "#restart" do
        let(:control_method) { :restart }
        before do
          stub_request(:any, mock_href(app_links['RESTART']['relative'], true)).
            with(:body => { 'event' => 'restart' }). # This is the critical part
            to_return({ :body => { :data => 'restart' }.to_json, :status => 200 })
        end
        it_should_behave_like "a control method"
      end

      context "#delete" do
        let(:control_method) { :delete }
        before do
          stub_request(:any, mock_href(app_links['DELETE']['relative'], true)).
            to_return({ :body => { :data => 'delete' }.to_json, :status => 200 })
        end
        it_should_behave_like "a control method"
      end

      context "#destroy" do
        let(:control_method) { :destroy }
        before do
          stub_request(:any, mock_href(app_links['DELETE']['relative'], true)).
            to_return({ :body => { :data => 'destroy' }.to_json, :status => 200 })
        end
        it_should_behave_like "a control method"
      end
    end
  end
end

