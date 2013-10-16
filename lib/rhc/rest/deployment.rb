module RHC
  module Rest
    class Deployment < Base
      define_attr :id, :ref, :sha1, :artifact_url, :hot_deploy, :created_at, :force_clean_build, :activations

      def <=>(other)
       other.created_at <=> created_at
      end
    end
  end
end
