module RHC
  module Rest
    class EnvironmentVariable < Base
      define_attr :id
      
      def destroy
        debug "Deleting alias #{self.id}"
        rest_method "DELETE"
      end
      alias :delete :destroy
      
    end
  end
end