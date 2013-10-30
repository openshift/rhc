require 'rhc/rest/activation'

module RHC
  module Rest
    class Deployment < Base
      define_attr :id, :ref, :sha1, :artifact_url, :hot_deploy, :created_at, :force_clean_build, :activations

      def activations
        @activations ||=
          attributes['activations'].map{|activation| Activation.new({:created_at => RHC::Helpers.datetime_rfc3339(activation)}, client)}.sort
      end

      def <=>(other)
       other.created_at <=> created_at
      end
    end
  end
end
