require 'rubygems'
require 'stringio'
require 'rhc/vendor/zliby'
require 'archive/tar/minitar'
include Archive::Tar

TAR_BIN = 'tar'
TAR_BIN = '/usr/bin/gnutar' if File.executable?('/usr/bin/gnutar')

module RHC

	module TarGz

    def self.contains(filename, search)
      
      return false if ! (File.file? filename and File.basename(filename).downcase =~ /.\.tar\.gz$/i)

      contains = false
      if RHC::Helpers.windows? then
        search = /#{search.to_s}/ if ! search.is_a?(Regexp)
        begin
          RHC::Vendor::Zlib::GzipReader.open(filename) do |gz|
            Minitar::Reader.open gz do |tar|
              tar.each_entry do |entry|
                if entry.full_name =~ search
                  contains = true
                end
              end
            end
          end
        rescue RHC::Vendor::Zlib::GzipFile::Error
          return false
        end
      else
        `#{TAR_BIN} --wildcards -tf #{filename} '#{search.to_s}'`
        contains = $?.exitstatus == 0
      end
      contains
    end

	end

end