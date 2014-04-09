module RHC
  module Rest
    class Team < Base

      define_attr :id, :name, :global

      def global?
        global
      end

      def <=>(team)
        return self.name <=> team.name
      end

      def to_s
        self.name
      end
    end
  end
end