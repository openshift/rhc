# From Rails core_ext/object.rb
require 'rhc/json'
require 'open-uri'
require 'httpclient'

class Object
  def present?
    !blank?
  end
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def presence
    present? ? self : nil
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

  def strip_heredoc
    indent = scan(/^[ \t]*(?=\S)/).min.size || 0
    gsub(/^[ \t]{#{indent}}/, '').
      gsub(/(\b|\S)[^\S\n]*\n(\S)/m, '\1 \2').
      gsub(/\n+\Z/, '').
      gsub(/\n{3,}/, "\n\n")
  end

  ANSI_ESCAPE_SEQUENCE = /\e\[(\d{1,2}(?:;\d{1,2})*[@-~])/
  ANSI_ESCAPE_MATCH = '\e\[\d+(?:;\d+)*[@-~]'
  CHAR_SKIP_ANSI = "(?:(?:#{ANSI_ESCAPE_MATCH})+.?|.(?:#{ANSI_ESCAPE_MATCH})*)"

  #
  # Split the given string at limit, treating ANSI escape sequences as
  # zero characters in length.  Will insert an ANSI reset code (\e[0m)
  # at the end of each line containing an ANSI code, assuming that a
  # reset was not in the wrapped segment.
  #
  # All newlines are preserved.
  #
  # Lines longer than limit without natural breaks will be forcibly 
  # split at the exact limit boundary.
  #
  # Returns an Array
  #
  def textwrap_ansi(limit, breakword=true)
    re = breakword ? /
      ( 
        # Match substrings that end in whitespace shorter than limit
        #{CHAR_SKIP_ANSI}{1,#{limit}} # up to limit
        (?:\s+|$)                     # require the limit to end on whitespace
        |
        # Match substrings equal to the limit
        #{CHAR_SKIP_ANSI}{1,#{limit}} 
      )
      /x :
      /
      ( 
        # Match substrings that end in whitespace shorter than limit
        #{CHAR_SKIP_ANSI}{1,#{limit}}
        (?:\s|$)                     # require the limit to end on whitespace
        |
        # Match all continguous whitespace strings
        #{CHAR_SKIP_ANSI}+?
        (?:\s|$)
        (?:\s+|$)?
      )
      /x

    split("\n",-1).inject([]) do |a, line|
      if line.length < limit
        a << line 
      else
        line.scan(re) do |segment, other|
          # short escape sequence matches have whitespace from regex
          a << segment.rstrip   
          # find any escape sequences after the last 0m reset, in order
          escapes = segment.scan(ANSI_ESCAPE_SEQUENCE).map{ |e| e.first }.reverse.take_while{ |e| e != '0m' }.uniq.reverse
          if escapes.present?
            a[-1] << "\e[0m"
            # TODO: Apply the unclosed sequences to the beginning of the
            #       next string
          end
        end
      end
      a
    end
  end

  def strip_ansi
    gsub(ANSI_ESCAPE_SEQUENCE, '')
  end
end

unless HTTP::Message.method_defined? :ok?
  #:nocov:
  class HTTP::Message
    def ok?
      HTTP::Status.successful?(status)
    end
  end
  #:nocov:
end

unless DateTime.method_defined? :to_time 
  #:nocov:
  class DateTime
    def to_time
      Time.parse(to_s)
    end
  end
  #:nocov:
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
  def reverse_merge!(other_hash)
    # right wins if there is no left
    merge!( other_hash ){|key,left,right| left }
  end
end
