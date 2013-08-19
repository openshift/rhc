module RHC
  module Rest
    class EnvironmentVariable < Base
      define_attr :name, :value

      def to_hash
        { :name => name, :value => value }
      end

      def <=>(other)
        name <=> other.name
      end
    end
  end
end
