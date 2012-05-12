require 'commander/runner'
require 'commander/delegates'
require 'rhc/commands'

module RHC:CLI

  include Commander::Delegates

  def start(args)
    program :name,        'rhc'
    program :version,     '0.0.0' #FIXME pull from versions.rb
    program :description, 'Command line interface for OpenShift.'

    RHC::Commands.load
    Commander::Runner.new(args).run!
  end
end
