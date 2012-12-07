module RHC
  module CartridgeHelpers

    def find_cartridge(rest_obj, cartridge_name, type="embedded")
      carts = find_cartridges(rest_obj, [cartridge_name], type)

      if carts.length == 0
        valid_carts = rest_obj.cartridges.collect { |c| c.name if c.type == type }.compact
        if valid_carts.length > 0
          msg = "Valid cartridges are (#{valid_carts.join(', ')})."
        else
          msg = "No cartridges have been added to this app."
        end
        raise RHC::CartridgeNotFoundException, "Invalid cartridge specified: '#{cartridge_name}'. #{msg}"
      elsif carts.length > 1
        msg = "Multiple cartridge versions match your criteria. Please specify one."
        carts.each { |cart| msg += "\n  #{cart.name}" }
        raise RHC::MultipleCartridgesException, msg
      end

      carts[0]
    end

    def find_cartridges(rest_obj, cartridge_list, type='embedded')
      rest_obj.find_cartridges :regex => cartridge_list.collect { |c| cart_regex c }.join('|'), :type => type
    end

    private

    def cart_regex(cart)
      "^#{cart.rstrip}(-[0-9\.]+){0,1}$"
    end
  end
end
