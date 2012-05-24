require 'rubygems'
require 'stringio'
require 'vendor/zliby'
require 'archive/tar/minitar'
include Archive::Tar

module RHC

	module TarGz

    def self.contains(filename, search)
      return false if ! (File.file? filename and File.basename(filename).downcase =~ /.\.tar\.gz$/i)
      search = /#{search.to_s}/ if ! search.is_a?(Regexp)
      contains = false
      begin
        Rhc::Vendor::Zlib::GzipReader.open(filename) do |gz|
          Minitar::Reader.open gz do |tar|
            tar.each_entry do |entry|
              if entry.full_name =~ search
                contains = true
              end
            end
          end
        end
      rescue Rhc::Vendor::Zlib::GzipFile::Error
        return false
      end
      contains
    end

	end

end