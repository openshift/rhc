module RHCHelper
  module API
    def new_client
      RHC::Rest::Client.new(:url => $end_point, :user => $username, :password => $password, :verify_mode => OpenSSL::SSL::VERIFY_NONE)
    end
  end
end
