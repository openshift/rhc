require 'spec_helper'
require 'rest_spec_helper'
require 'rhc-common'

# The existence of this file is a stopgap to provide test coverage
# for a specific bug fix (BZ836882). This test should be migrated
# to a more appropriate location when rhc-common is refactored out
# of existence.

describe RHC do
  let(:client_links) { mock_response_links(mock_client_links) }
  let(:domain_links) { mock_response_links(mock_domain_links('mock_domain')) }
  let(:user_info) {
    { 'user_info' => { 'domains' => [ { 'namespace' => 'mock_domain' } ] } }
  }
  context "#create_app" do
    context " creating a scaling app" do
      before do
        stub_request(:get, mock_href('broker/rest/api', true)).
          to_return({ :body   => { :data => client_links }.to_json,
                      :status => 200
                    })
        stub_request(:any, mock_href(client_links['LIST_DOMAINS']['relative'], true)).
          to_return({ :body   => {
                        :type => 'domains',
                        :data =>
                        [{ :id    => 'mock_domain',
                           :links => domain_links,
                         }]
                      }.to_json,
                      :status => 200
                    })
        stub_request(:any, mock_href(domain_links['ADD_APPLICATION']['relative'], true)).
          to_raise(Rhc::Rest::ServerErrorException.new("Mock server error"))
        RHC.stub!(:print_response_err) { |output| @test_output = output; exit 1 }
      end
      it "posts an error message if the Rest API encounters a server error" do
        lambda{ RHC.create_app( mock_uri, Net::HTTP, user_info,
                                    'mock_app', 'mock_type', mock_user, mock_pass,
                                    nil, false, false, false, 'small', true) }.
          should raise_error(SystemExit)
        @test_output.body.should match(/Mock server error/)
      end
      after do
        RHC.unstub!(:print_response_err)
      end
    end
  end
end
