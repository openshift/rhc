module RHC
  module Rest
    class Activation < Base
      define_attr :created_at

      def <=>(other)
       other.created_at <=> created_at
      end
    end
  end
end
