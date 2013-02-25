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
        "token_#{Base64.encode64(Digest::MD5.digest(key)).gsub(/[^\w\@]/,'')}"
      end

      def []=(key, value)
        file = path(key)
        FileUtils.mkdir_p File.dirname(file)
        File.open(file, 'w'){ |f| f.write(value) }
        File.chmod(0600, file)
        value
      end

      def [](key)
        s = IO.read(path(key)).presence
        s = s.strip.gsub(/[\n\r\t]/,'') if s
        s
      rescue Errno::ENOENT
        nil
      end

      def key(login, server)
        "#{login || ''}@#{server}"
      end

  end
end
