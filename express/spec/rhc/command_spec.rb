require 'spec_helper'
require 'rhc/commands/base'

describe RHC::Commands::Base do

  describe :class_new do

    it "should register a simple command" do
      lambda { define_test_command }.should change(commands, :length).by(1)
    end
  end
end
