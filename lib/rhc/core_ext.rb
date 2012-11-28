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

class String
  # Wrap string by the given length, and join it with the given character.
  # The method doesn't distinguish between words, it will only work based on
  # the length.
  def wrap(wrap_length=80, char="\n")
    scan(/.{#{wrap_length}}|.+/).join(char)
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

class Hash
  def stringify_keys!
    keys.each do |key|
      v = delete(key)
      if v.is_a? Hash
        v.stringify_keys!
      elsif v.is_a? Array
        v.each{ |value| value.stringify_keys! if value.is_a? Hash }
      end
      self[(key.to_s rescue key) || key] = v
    end
    self
  end
  def slice!(*args)
    s = []
    args.inject([]) do |a, k|
      s << [k, delete(k)] if has_key?(k)
    end
    s
  end
end

# Some versions of highline get in an infinite loop when trying to wrap.
# Fixes BZ 866530.
class HighLine

  def wrap_line(line)
    wrapped_line = []
    i = chars_in_line = 0
    word = []

    while i < line.length
      # we have to give a length to the index because ruby 1.8 returns the
      # byte code when using a single fixednum index
      c = line[i, 1]
      color_code = nil
      # escape character probably means color code, let's check
      if c == "\e"
        color_code = line[i..i+6].match(/\e\[\d{1,2}m/)
        if color_code
          # first the existing word buffer then the color code
          wrapped_line << word.join.wrap(@wrap_at) << color_code[0]
          word.clear

          i += color_code[0].length
        end
      end

      # visible character
      if !color_code
        chars_in_line += 1
        word << c

        # time to wrap the line?
        if chars_in_line == @wrap_at
          if c == ' ' or line[i+1, 1] == ' ' or word.length == @wrap_at
            wrapped_line << word.join
            word.clear
          end

          wrapped_line[-1].rstrip!
          wrapped_line << "\n"

          # consume any spaces at the begining of the next line
          word = word.join.lstrip.split(//)
          chars_in_line = word.length

          if line[i+1, 1] == ' '
            i += 1 while line[i+1, 1] == ' '
          end

        else
          if c == ' '
            wrapped_line << word.join
            word.clear
          end
        end

        i += 1
      end
    end

    wrapped_line << word.join
    wrapped_line.join
  end

  def wrap(text)
    wrapped_text = []
    lines = text.split(/\r?\n/)
    lines.each_with_index do |line, i|
      wrapped_text << wrap_line(i == lines.length - 1 ? line : line.rstrip)
    end

    return wrapped_text.join("\n")
  end
end
