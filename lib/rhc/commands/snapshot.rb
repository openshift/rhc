require 'rhc/commands/base'

module RHC::Commands
  class Snapshot < Base
    summary "Save the current state of your application locally"
    syntax "<action>"
    description <<-DESC
      Snapshots allow you to export the current state of your OpenShift application
      into an archive on your local system, and then to restore it later.

      The snapshot archive contains the Git repository, dumps of any attached databases,
      and any other information that the cartridges decide to export.

      WARNING: Both 'save' and 'restore' will stop the application and then restart
      after the operation completes.
      DESC
    alias_action :"app snapshot", :root_command => true
    default_action :help

    summary "Save a snapshot of your app to disk"
    syntax "<application> [--filepath FILE]"
    takes_application :argument => true
    option ["-f", "--filepath FILE"], "Local path to save tarball (default: ./$APPNAME.tar.gz)"
    option ["--deployment"], "Snapshot as a deployable file which can be deployed with 'rhc deploy'"
    alias_action :"app snapshot save", :root_command => true, :deprecated => true
    def save(app)

      rest_app = find_app

      raise RHC::DeploymentsNotSupportedException.new if options.deployment && !rest_app.supports?("DEPLOY")

      filename = options.filepath ? options.filepath : "#{rest_app.name}.tar.gz"

      save_snapshot(rest_app, filename, options.deployment, options.ssh)

      0
    end

    summary "Restores a previously saved snapshot"
    syntax "<application> [--filepath FILE]"
    takes_application :argument => true
    option ["-f", "--filepath FILE"], "Local path to restore tarball"
    alias_action :"app snapshot restore", :root_command => true, :deprecated => true
    def restore(app)
      rest_app = find_app
      filename = options.filepath ? options.filepath : "#{rest_app.name}.tar.gz"

      if File.exists? filename
        restore_snapshot(rest_app, filename, options.ssh)
      else
        raise RHC::SnapshotRestoreException.new "Archive not found: #{filename}"
      end
      0
    end

    protected
      include RHC::SSHHelpers

  end
end
