require 'commander/user_interaction'

module RHC::Helpers
  # helpers always have Commander UI available
  include Commander::UI
  include Commander::UI::AskForClass
end
