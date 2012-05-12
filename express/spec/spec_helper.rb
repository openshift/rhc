require 'rubygems'
#require 'spec'
require 'webmock/rspec'
#include 'mocha'
require 'rhc/cli'

include WebMock::API

def define_test_command
  Class.new(RHC::Commands::Base) do
    def run
      1      
    end
  end
end
