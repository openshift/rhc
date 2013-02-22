require 'rhc/rest/base'

module RHC
  module Rest
    class Authorization < Base
      define_attr :token, :note, :expires_in, :expires_in_seconds, :scopes, :created_at
      alias_method :creation_time, :created_at
    end
  end
end
