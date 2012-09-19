require 'rhc/commands/base'
module RHC::Commands
  class Snapshot < Base
    summary "Pull down application snapshot for a user."
    syntax "<action>"
    alias_action :"app snapshot", :root_command => true
    default_action :save

    summary "Pull down application snapshot for a user."
    syntax "<application>"
    option ["-n", "--namespace namespace"], "Namespace of the application you are port forwarding to", :context => :namespace_context, :required => true
    option ["-s", "--save filename"], "Local path to save tarball (default: ./$APPNAME.tar.gz)"
    option ["-r", "--restore filename"], "Local path of the tarball to restore (restores git and application data folders found in archive)"
    argument :app, "Application you are port forwarding to (required)", ["-a", "--app app"]
    alias_action :"app snapshot", :root_command => true
    def save(app)
      ssh_uri = URI.parse(rest_client.find_domain(options.namespace).find_application(app).ssh_url)
      filename = "#{app}.tar.gz" unless options.save || options.restore

      ssh_cmd = "ssh #{ssh_uri.user}@#{ssh_uri.host} 'snapshot' > #{filename}"
      debug ssh_cmd

      say "Pulling down a snapshot to #{filename}..."
      
      begin

        if ! RHC::Helpers.windows?
          output = `#{ssh_cmd}`
          if $?.exitstatus != 0
            debug output
            raise RHC::SnapshotSaveException.new "Error in trying to save snapshot. You can try to save manually by running:\n#{ssh_cmd}"
          end
        else
          Net::SSH.start(ssh_uri.host, ssh_uri.user) do |ssh|
            File.open(filename, 'wb') do |file|
              ssh.exec! "snapshot" do |channel, stream, data|
                if stream == :stdout
                  file.write(data)
                else
                  debug data
                end
              end
            end
          end
        end
      rescue Exception => e
        debug e.backtrace
        raise RHC::SnapshotSaveException.new "Error in trying to save snapshot. You can try to save manually by running:\n#{ssh_cmd}"
      end
      results { say "Success" }
      0
    end

    summary "Pull down application snapshot for a user."
    syntax "<application>"
    option ["-n", "--namespace namespace"], "Namespace of the application you are port forwarding to", :context => :namespace_context, :required => true
    argument :app, "Application you are port forwarding to (required)", ["-a", "--app app"]
    alias_action :"app snapshot", :root_command => true
    def restore(app)

      if File.exists? filename

        if ! RHC::Helpers.windows? and ! RHC::TarGz.contains filename, './*/' + app_name

          puts "Archive at #{filename} does not contain the target application: ./*/#{app_name}"
          puts "If you created this archive rather than exported with rhc-snapshot, be sure"
          puts "the directory structure inside the archive starts with ./<app_uuid>/"
          puts "i.e.: tar -czvf <app_name>.tar.gz ./<app_uuid>/"
          return 255

        else

          include_git = RHC::Helpers.windows? ? false : RHC::TarGz.contains(filename, './*/git')

          ssh_cmd = "cat #{filename} | ssh #{app_uuid}@#{app_name}-#{namespace}.#{rhc_domain} 'restore#{include_git ? ' INCLUDE_GIT' : ''}'"
          puts "Restoring from snapshot #{filename}..."
          puts ssh_cmd if debug
          puts 

          begin
            if ! RHC::Helpers.windows?
              output = `#{ssh_cmd}`
              if $?.exitstatus != 0
                puts output
                puts "Error in trying to restore snapshot.  You can try to restore manually by running:"
                puts
                puts ssh_cmd
                puts
                return 1
              end
            else
              ssh = Net::SSH.start("#{app_name}-#{namespace}.#{rhc_domain}", app_uuid)
              ssh.open_channel do |channel|
                channel.exec("restore#{include_git ? ' INCLUDE_GIT' : ''}") do |ch, success|
                  channel.on_data do |ch, data|
                    puts data
                  end
                  channel.on_extended_data do |ch, type, data|
                    puts data
                  end
                  channel.on_close do |ch|
                    puts "Terminating..."
                  end
                  File.open(filename, 'rb') do |file|
                    file.chunk(1024) do |chunk|
                      channel.send_data chunk
                    end
                  end
                  channel.eof!
                end
              end
              ssh.loop
            end
          rescue Exception => e
            puts e.backtrace
            puts "Error in trying to restore snapshot.  You can try to restore manually by running:"
            puts
            puts ssh_cmd
            puts
            return 1
          end

        end
      else
        puts "Archive not found: #{filename}"
        return 255
      end

      results { say "Success" }
      0
    end

  end
end
