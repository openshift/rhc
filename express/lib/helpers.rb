require 'rubygems'
require 'vendor/okjson'
require 'stringio'
require 'vendor/pr/zlib'
require 'archive/tar/minitar'
include Archive::Tar

module Rhc

  class Platform
    def self.jruby? ; RUBY_PLATFORM =~ /java/i end
    def self.windows? ; RUBY_PLATFORM =~ /win(32|dows|ce)|djgpp|(ms|cyg|bcc)win|mingw32/i end
    def self.unix? ; !jruby? && !windows? end
  end

  class Tar
    def self.contains(tar_gz, search)
      search = /#{search.to_s}/ if ! search.is_a?(Regexp)
      file = File.open(tar_gz)
      begin
        tgz = Rhc::Vendor::Zlib::GzipReader.new(file)
      rescue Rhc::Vendor::Zlib::GzipFile::Error
        return false
      end
      Minitar::Reader.new(tgz).each_entry do |file|
        if file.full_name =~ search
          return true
        end
      end
      false
    end
  end

  class Json

    def self.decode(string, options={})
      string = string.read if string.respond_to?(:read)
      result = Rhc::Vendor::OkJson.decode(string)
      options[:symbolize_keys] ? symbolize_keys(result) : result
    end

    def self.encode(object, options={})
      Rhc::Vendor::OkJson.valenc(stringify_keys(object))
    end

    def self.symbolize_keys(object)
      modify_keys(object) do |key|
        key.is_a?(String) ? key.to_sym : key
      end
    end

    def self.stringify_keys(object)
      modify_keys(object) do |key|
        key.is_a?(Symbol) ? key.to_s : key
      end
    end

    def self.modify_keys(object, &modifier)
      case object
      when Array
        object.map do |value|
          modify_keys(value, &modifier)
        end
      when Hash
        object.inject({}) do |result, (key, value)|
          new_key   = modifier.call(key)
          new_value = modify_keys(value, &modifier)
          result.merge! new_key => new_value
        end
      else
        object
      end
    end
  end

  class JsonError < ::StandardError; end

  class Input

    def self.ask_for_password_on_unix(prompt = "Password: ")
      raise 'Could not ask for password because there is no interactive terminal (tty)' unless $stdin.tty?
      $stdout.print prompt unless prompt.nil?
      $stdout.flush
      raise 'Could not disable echo to ask for password securely' unless system 'stty -echo'
      password = $stdin.gets
      password.chomp! if password
      password
    ensure
      raise 'Could not re-enable echo while asking for password' unless system 'stty echo'
    end

    def self.ask_for_password_on_windows(prompt = "Password: ")
      raise 'Could not ask for password because there is no interactive terminal (tty)' unless $stdin.tty?
      require 'Win32API'
      char = nil
      password = ''
      $stdout.print prompt unless prompt.nil?
      $stdout.flush
      while char = Win32API.new("crtdll", "_getch", [ ], "L").Call do
        break if char == 10 || char == 13 # return or newline
        if char == 127 || char == 8 # backspace and delete
          password.slice!(-1, 1)
        else
          password << char.chr
        end
      end
      puts
      password
    end

    def self.ask_for_password_on_jruby(prompt = "Password: ")
      raise 'Could not ask for password because there is no interactive terminal (tty)' unless $stdin.tty?
      require 'java'
      include_class 'java.lang.System'
      include_class 'java.io.Console'
      $stdout.print prompt unless prompt.nil?
      $stdout.flush
      java.lang.String.new(System.console().readPassword(prompt));
    end

    def self.ask_for_password(prompt = "Password: ")
      %w|windows unix jruby|.each do |platform|
        eval "return ask_for_password_on_#{platform}(prompt) if Rhc::Platform.#{platform}?"
      end
      raise "Could not read password on unknown Ruby platform: #{RUBY_DESCRIPTION}"
    end

  end

end
