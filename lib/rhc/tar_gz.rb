require 'stringio'
require 'archive/tar/minitar'
include Archive::Tar

TAR_BIN = File.executable?('/usr/bin/gnutar') ? '/usr/bin/gnutar' : 'tar'

module RHC

  module TarGz

    def self.contains(filename, search, force_ruby=false)

      return false if ! (File.file? filename and File.basename(filename).downcase =~ /.\.t(ar\.)?gz$/i)

      regex = Regexp.new search
      if RHC::Helpers.windows? or RHC::Helpers.mac? or force_ruby
        begin
          zlib::GzipReader.open(filename) do |gz|
            Minitar::Reader.open gz do |tar|
              tar.each_entry do |entry|
                if entry.full_name =~ regex
                  return true
                end
              end
            end
          end
        rescue zlib::GzipFile::Error, zlib::GzipFile::Error
          false
        end
      else
        # combining STDOUT and STDERR (i.e., 2>&1) does not suppress output
        # when the specs run via 'bundle exec rake spec'
        system "#{TAR_BIN} --wildcards -tf '#{filename}' '#{regex.source}' 2>/dev/null >/dev/null"
      end
    end

    private
      def self.zlib
        #:nocov:
        require 'zlib' rescue nil
        if defined? Zlib::GzipReader 
          Zlib
        else
          require 'rhc/vendor/zliby'
          RHC::Vendor::Zlib
        end
        #:nocov:
      end
  end

end
