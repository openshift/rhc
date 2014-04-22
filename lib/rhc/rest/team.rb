module RHC
  module Rest
    class Team < Base

      include Membership

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

      def destroy(force=false)
        debug "Deleting team #{name} (#{id})"
        rest_method "DELETE"
      end
      alias :delete :destroy

      def default_member_role
        'view'
      end

    end
  end
end