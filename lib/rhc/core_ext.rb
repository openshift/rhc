# From Rails core_ext/object.rb
require 'rhc/json'
require 'open-uri'
require 'highline'

class Object
  def present?
    !blank?
  end
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  # Avoid a conflict if to_json is already defined
  unless Object.new.respond_to? :to_json
    def to_json(options=nil)
      RHC::Json.encode(self)
    end
  end
end

class File
  def chunk(chunk_size=1024)
    yield read(chunk_size) until eof?
  end
end

#
# Allow http => https redirection, see 
# http://bugs.ruby-lang.org/issues/859 to 1.8.7 for rough
# outline of change.
#
module OpenURI
  def self.redirectable?(uri1, uri2) # :nodoc:
    # This test is intended to forbid a redirection from http://... to
    # file:///etc/passwd.
    # However this is ad hoc.  It should be extensible/configurable.
    uri1.scheme.downcase == uri2.scheme.downcase ||
    (/\A(?:http|ftp)\z/i =~ uri1.scheme && /\A(?:https?|ftp)\z/i =~ uri2.scheme)
  end
end

# Some versions of highline get in an infinite loop when trying to wrap.
# Fixes BZ 866530.
class HighLine
  def wrap( text )
    wrapped_text = []
    text.each_line do |line|
      word = []
      i = chars_in_line = 0
      chars = line.split(//)
      while i < chars.length do
        c = chars[i]
        color_code = nil
        # escape character probably means color code, let's check
        if c == "\e"
          color_code = line[i..-1].match(/\e\[\d{1,2}m/)
          # it's a color code
          if color_code
            i += color_code[0].length
            # first the existing word buffer then the color code
            wrapped_text << word.join << color_code[0]
            word.clear
          end
        end
        # not a color code sequence
        if !color_code
          chars_in_line += 1
          # time to wrap the line?
          if chars_in_line == @wrap_at
            wrapped_text.pop if wrapped_text.last =~ / /
            wrapped_text << "\n"
            chars_in_line = 0
          end
          # space, so move the word to wrapped buffer and start a new word
          if c =~ / /
            wrapped_text << word.join << ' '
            word.clear
            chars_in_line += 1
          # any other character
          else
            word << c
          end
          i += 1
        end
      end
      # moves the rest of the word buffer
      wrapped_text << word.join
    end
    return wrapped_text.join
  end

end
