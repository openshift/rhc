require File.expand_path('../../test_helper', __FILE__)

class CommandTest < Test::Unit::TestCase
  
  def define_test_command
    Class.new(RHC::Commands::Base) do
      def run
        1      
      end
    end
    
  end

  test 'should register a command' do
    assert_difference('commands.length', 1) do
      define_test_command
    end
  end
end
