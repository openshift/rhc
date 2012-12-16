module RHC
  module CartridgeHelpers

    def find_cartridge(rest_obj, cartridge_name, type="embedded")
      carts = find_cartridges(rest_obj, [cartridge_name], type)

      if carts.length == 0
        valid_carts = rest_obj.cartridges.collect { |c| c.name if c.type == type }.compact

        msg = if RHC::Rest::Application === rest_obj
                "Cartridge '#{cartridge_name}' cannot be found in application '#{rest_obj.name}'."
              else
                "Cartridge '#{cartridge_name}' is not a valid cartridge name."
              end

        unless valid_carts.empty?
          msg += "  Valid cartridges are (#{valid_carts.join(', ')})."
        end

        raise RHC::CartridgeNotFoundException, msg
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
