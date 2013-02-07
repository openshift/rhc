module RHC::Auth
  class TokenStore
    def initialize(dir)
      @dir = dir
    end

    def get(login, server)
      self[key(login,server)]
    end

    def put(login, server, token)
      self[key(login,server)] = token
    end

    def clear
      Dir[File.join(@dir, "token_*")].
        each{ |f| File.delete(f) unless File.directory?(f) }.
        present?
    end

    private
      def path(key)
        File.join(@dir, filename(key))
      end

      def filename(key)
        "token_#{Digest::MD5.digest(key).gsub(/[^\w\@]/,'_')}"
      end

      def []=(key, value)
        File.open(path(key), 'w'){ |f| f.write(value) }
        File.chmod(0600, path(key))
        value
      end

      def [](key)
        IO.read(path(key)).presence# rescue nil
      rescue Errno::ENOENT
        nil
      end

      def key(login, server)
        "#{login || ''}@#{server}"
      end

  end
end
