module RHC
  module Rest
    class GearGroup < Base
      define_attr :gears, :cartridges, :gear_profile, :additional_gear_storage, :base_gear_storage

      def name(gear)
        gear['name'] ||= "#{group.cartridges.collect{ |c| c['name'] }.join('+')}:#{gear['id']}"
      end

      def quota
        return nil unless base_gear_storage
        ((additional_gear_storage || 0) + base_gear_storage) * 1024 * 1024 * 1024
      end
    end
  end
end
