require 'commander/user_interaction'

module RHC::Helpers
  # helpers always have Commander UI available
  include Commander::UI
  include Commander::UI::AskForClass

  ##
  # section
  #
  # highline helper mixin which correctly formats block of say and ask
  # output to have correct margins.  section remembers the last margin
  # used and calculates the relitive margin from the previous section.
  # For example:
  #
  # section(bottom=1) do
  #   say "Hello"
  # end
  #
  # section(top=1) do
  #   say "World"
  # end
  #
  # Will output:
  #
  # > Hello
  # >
  # > World 
  #
  # with only one newline between the two.  Biggest margin wins.
  #
  # params:
  #  top - top margin specified in lines
  #  bottom - bottom margin specified in line
  #
  @@section_bottom_last = 0
  def section(params={}, &block)
    top = params[:top]
    top = 0 if top.nil?
    bottom = params[:bottom]
    bottom = 0 if bottom.nil?

    # add more newlines if top is greater than the last section's bottom margin
    top_margin = @@section_bottom_last

    # negitive previous bottoms indicate that an untracked newline was
    # printed and so we do our best to negate it since we can't remove it
    if top_margin < 0
      top += top_margin
      top_margin = 0
    end

    until top_margin >= top
      say "\n"
      top_margin += 1
    end

    block.call

    bottom_margin = 0
    until bottom_margin >= bottom
      say "\n"
      bottom_margin += 1
    end

    @@section_bottom_last = bottom
  end

  ##
  # paragraph
  #
  # highline helper which creates a section with margins of 1, 1
  #
  def paragraph(&block)
    section(:top => 1, :bottom => 1, &block)
  end

  # Platform helpers
  def jruby? ; RUBY_PLATFORM =~ /java/i end
  def windows? ; RUBY_PLATFORM =~ /win(32|dows|ce)|djgpp|(ms|cyg|bcc)win|mingw32/i end
  def unix? ; !jruby? && !windows? end
end
