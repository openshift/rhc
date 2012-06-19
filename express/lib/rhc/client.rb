require 'rhc/helpers'

class RHC::Client
  def initialize() #auth info
  end

  include RHC::Helpers

  def get(uri, headers={})
    # absolute uris are called directly, relative uris are called with
    # the rest api root, and server relative uris are called against the
    # host.  Allow simple templatization via t()
  end
  def t(uri, opts)
    # templatize uri using AddressableTemplate and opts
  end
end
