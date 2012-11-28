require 'rhc/rest/base'

module RHC
  module Rest
    class GearGroup < Base
      include Rest
      define_attr :gears, :cartridges
    end
  end
end
