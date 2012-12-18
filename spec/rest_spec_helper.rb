require 'webmock/rspec'
require 'rhc/rest'
require 'rhc/rest/mock'
require 'rhc/exceptions'
require 'base64'

Spec::Matchers.define :have_same_attributes_as do |expected|
  match do |actual|
    (actual.instance_variables == expected.instance_variables) &&
      (actual.instance_variables.map { |i| instance_variable_get(i) } ==
       expected.instance_variables.map { |i| instance_variable_get(i) })
  end
end

# ruby 1.8 does not have strict_encode
if RUBY_VERSION.to_f == 1.8
  module Base64
    def strict_encode64(value)
      encode64(value).delete("\n")
    end
  end
end

module RestSpecHelper
  include RHC::Rest::Mock::Helpers
  include RHC::Rest::Mock
end

Spec::Runner.configure do |configuration|
  include(RestSpecHelper)
end
