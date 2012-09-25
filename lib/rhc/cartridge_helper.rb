module RHC
  module CartridgeHelpers
    def find_cartridge(rest_obj, cartridge_name, type="embedded")
      carts = rest_obj.find_cartridges :regex => cart_regex(cartridge_name), :type => type

      if carts.length == 0
        valid_carts = rest_obj.cartridges.collect { |c| c.name if c.type == type }.compact
        raise RHC::CartridgeNotFoundException, "Invalid cartridge specified: '#{cartridge_name}'. Valid cartridges are (#{valid_carts.join(', ')})."
      elsif carts.length > 1
        msg = "Multiple cartridge versions match your criteria. Please specify one."
        carts.each { |cart| msg += "\n  #{cart.name}" }
        raise RHC::MultipleCartridgesException, msg
      end

      carts[0]
    end

    def cart_regex(cart)
      "^#{cart.rstrip}(-[0-9\.]+){0,1}$"
    end
  end
end
