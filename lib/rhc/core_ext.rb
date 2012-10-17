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
# Copied from the 1.6.16 version of highline. Fixes BZ 866530.
class HighLine
  def wrap( text )
    wrapped = [ ]
    text.each_line do |line|
      # take into account color escape sequences when wrapping
      line_clean = clean_up_line(line)
      line_clean_wrapped = line_clean.clone
      while line_clean_wrapped =~ /([^\n]{#{@wrap_at + 1},})/
        search = $1.dup
        replace = $1.dup
        if index = replace.rindex(" ", @wrap_at)
          replace[index, 1] = "\n"
          replace.sub!(/\n[ \t]+/, "\n")
          line_clean_wrapped.sub!(search, replace)
        else
          line_clean_wrapped[$~.begin(1) + @wrap_at, 0] = "\n"
        end
      end
      wrapped << line.sub(line_clean, line_clean_wrapped)
    end
    return wrapped.join
  end
  def clean_up_line( string_with_escapes )
    string_with_escapes.to_s.gsub(/\e\[\d{1,2}m/, "")
  end
end
