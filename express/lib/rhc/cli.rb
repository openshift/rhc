require 'commander'
require 'commander/runner'
require 'commander/delegates'
require 'rhc/commands'

include Commander::UI
include Commander::UI::AskForClass

module RHC
  module CLI

    extend Commander::Delegates

    def self.start(args)
      program :name,        'rhc'
      program :version,     '0.0.0' #FIXME pull from versions.rb
      program :description, 'Command line interface for OpenShift.'

      RHC::Commands.load
      run!
    end
  end
end
