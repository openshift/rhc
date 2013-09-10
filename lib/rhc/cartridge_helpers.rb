module RHC
  module CartridgeHelpers

    protected
      def check_cartridges(names, opts={}, &block)
        cartridge_names = Array(names).map{ |s| s.strip if s && s.length > 0 }.compact
        from = opts[:from] || all_cartridges

        cartridge_names.map do |name|
          next use_cart(RHC::Rest::Cartridge.for_url(name), name) if name =~ %r(\Ahttps?://)i

          name = name.downcase
          from.find{ |c| c.name.downcase == name } ||
          begin
            carts = from.select{ |c| match_cart(c, name) }
            if carts.empty?
              paragraph { list_cartridges(from) }
              raise RHC::CartridgeNotFoundException, "There are no cartridges that match '#{name}'."
            elsif carts.length == 1
              use_cart(carts.first, name)
            else
              carts.sort!.instance_variable_set(:@for, name)
              carts
            end
          end
        end.tap do |carts|
          yield carts if block_given?
        end.each do |carts|
          if carts.is_a? Array
            name = carts.instance_variable_get(:@for)
            paragraph { list_cartridges(carts) }
            raise RHC::MultipleCartridgesException, "There are multiple cartridges matching '#{name}'. Please provide the short name of the correct cart."
          end
        end
      end

      def use_cart(cart, for_cartridge_name)
        if cart.name.blank? and cart.custom?
          info "The cartridge '#{cart.url}' will be downloaded and installed"
        else
          info "Using #{cart.name}#{cart.display_name ? " (#{cart.display_name})" : ''} for '#{for_cartridge_name}'"
        end
        cart
      end

      def match_cart(cart, search)
        search = search.to_s.downcase.gsub(/[_\-\s]/,' ')
        [
           cart.name,
          (cart.tags || []).join(' '),
        ].compact.any?{ |s| s.present? && s.downcase.gsub(/[_\-\s]/,' ').include?(search) } || 
        search.length > 2 && [
          cart.description
        ].compact.any?{ |s| s.present? && !s.downcase.match(/\b#{search}\b/).nil? }
      end

      def web_carts_only
        lambda{ |cart|
          next cart unless cart.is_a? Array
          name = cart.instance_variable_get(:@for)
          matching = cart.select{ |c| not c.only_in_existing? }
          if matching.size == 1
            use_cart(matching.first, name)
          else
            matching.instance_variable_set(:@for, name)
            matching
          end
        }
      end

      def other_carts_only
        lambda{ |cart|
          next cart unless cart.is_a? Array
          name = cart.instance_variable_get(:@for)
          matching = cart.select{ |c| not c.only_in_new? }
          if matching.size == 1
            use_cart(matching.first, name)
          else
            matching.instance_variable_set(:@for, name)
            matching
          end
        }
      end

      def standalone_cartridges
        @standalone_cartridges ||= all_cartridges.select{ |c| c.type == 'standalone' }
      end

      def not_standalone_cartridges
        @not_standalone_cartridges ||= all_cartridges.select{ |c| c.type != 'standalone' }
      end

      def all_cartridges
        @all_cartridges = rest_client.cartridges
      end

      def list_cartridges(cartridges)
        carts = cartridges.map{ |c| [c.name, c.display_name || ''] }.sort{ |a,b| a[1].downcase <=> b[1].downcase }
        carts.unshift ['==========', '=========']
        carts.unshift ['Short Name', 'Full name']
        say table(carts)
      end

      def filter_jenkins_cartridges(tag)
        cartridges = all_cartridges.select { |c| (c.tags || []).include?(tag) && c.name =~ /\Ajenkins/i }.sort
        raise RHC::JenkinsNotInstalledOnServer if cartridges.empty?
        cartridges
      end

      def jenkins_cartridges
        @jenkins_cartridges ||= filter_jenkins_cartridges('ci')
      end

      def jenkins_client_cartridges
        @jenkins_client_cartridges ||= filter_jenkins_cartridges('ci_builder')
      end
  end
end
