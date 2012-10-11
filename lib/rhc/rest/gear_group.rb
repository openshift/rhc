require 'rhc/rest/base'

module RHC
  module Rest
    class GearGroup < Base
      include Rest
      attr_reader :gears, :cartridges
    end
  end
end
