require 'active_support/json'
require 'active_support/core_ext/object/to_json'

module RHCHelper
  module Persistable
    include ActiveSupport::JSON
    include Loggable

    def find_on_fs
      Dir.glob("#{RHCHelper::TEMP_DIR}/*.json").collect {|f| App.from_file(f)}
    end

    def from_file(filename)
      App.from_json(ActiveSupport::JSON.decode(File.open(filename, "r") {|f| f.readlines}[0]))
    end

    def from_json(json)
      app = App.new(json['type'], json['name'])
      app.embed = json['embed']
      app.mysql_user = json['mysql_user']
      app.mysql_password = json['mysql_password']
      app.mysql_hostname = json['mysql_hostname']
      app.uid = json['uid']
      return app
    end
  end

  module Persistify
    include ActiveSupport::JSON

    attr_accessor :file

    def persist
      json = self.to_json(:except => [:logger, :perf_logger])
      File.open(@file, "w") {|f| f.puts json}
    end
  end
end
