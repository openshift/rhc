require 'rubygems'
require 'stringio'
require 'vendor/pr/zlib'
require 'archive/tar/minitar'
include Archive::Tar

module RHC

	module TarGz

    def self.contains(filename, search)
      search = /#{search.to_s}/ if ! search.is_a?(Regexp)
      contains = false
      begin
        Rhc::Vendor::Zlib::GzipReader.open(filename) do |gzip|
          tar = Minitar::Reader.new(gzip)
          tar.each_entry do |entry|
            if entry.full_name =~ search
              contains = true
            end
          end
          tar.close
        end
      rescue Rhc::Vendor::Zlib::GzipFile::Error
        return false
      end
      contains
    end

	end

end