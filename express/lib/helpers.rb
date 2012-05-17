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

end
