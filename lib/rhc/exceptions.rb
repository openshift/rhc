module RHC
  class Exception < StandardError
    attr_reader :code
    def initialize(message=nil, code=1)
      super(message)
      @code = code
    end
  end

  class ConfirmationError < Exception
    def initialize(message="This action requires the --confirm option (or entering 'yes' at a prompt) to run.", code=1)
      super(message, code)
    end
  end

  class CartridgeNotFoundException < Exception
    def initialize(message="Cartridge not found")
      super message, 154
    end
  end

  class AliasNotFoundException < Exception
    def initialize(message="Alias not found")
      super message, 156
    end
  end

  class MultipleCartridgesException < Exception
    def initialize(message="Multiple cartridge found")
      super message, 155
    end
  end

  class EnvironmentVariableNotFoundException < Exception
    def initialize(message="Environment variable not found")
      super message, 157
    end
  end

  class EnvironmentVariablesNotSupportedException < Exception
    def initialize(message="Server does not support environment variables")
      super message, 158
    end
  end

  class EnvironmentVariableNotProvidedException < Exception
    def initialize(message="Environment variable not provided")
      super message, 159
    end
  end

  class JenkinsNotInstalledOnServer < Exception
    def initialize(message="There is no installed cartridge that exposes Jenkins")
      super message, 160
    end
  end

  class KeyNotFoundException < Exception
    def initialize(message="SSHKey not found")
      super message, 118
    end
  end

  class GitException < Exception
    def initialize(message="Git returned an error")
      super message, 216
    end
  end

  class GitPermissionDenied < GitException; end
  class GitDirectoryExists < GitException; end

  class DeprecatedError < RuntimeError; end

  class KeyFileNotExistentException < Exception
    def initialize(message="SSH Key file not found")
      super message, 128
    end
  end

  class KeyFileAccessDeniedException < Exception
    def initialize(message = "Insufficient acces to SSH Key file")
      super message, 128
    end
  end

  class KeyDataInvalidException < Exception
    def initialize(message = "SSH Key file contains invalid data")
      super message, 128
    end
  end

  class PermissionDeniedException < Exception
    def initialize(message="Permission denied")
      super message, 129
    end
  end

  class NoPortsToForwardException < Exception
    def initialize(message="No available ports to forward")
      super message, 102
    end
  end

  class PortForwardFailedException < Exception
    def initialize(message="Port forward failed")
      super message, 1
    end
  end

  class SnapshotSaveException < Exception
    def initialize(message="Error trying to save snapshot")
      super message, 130
    end
  end

  class SnapshotRestoreException < Exception
    def initialize(message="Error trying to restore snapshot")
      super message, 130
    end
  end

  class DeploymentNotFoundException < Exception
    def initialize(message="Deployment not found")
      super message, 131
    end
  end

  class DeploymentsNotSupportedException < Exception
    def initialize(message="The server does not support deployments")
      super message, 132
    end
  end

  class IncompatibleDeploymentTypeException < Exception
    def initialize(message="The artifact provided is not compatible with the app deployment type.")
      super message, 133
    end
  end

  class MissingScalingValueException < Exception
    def initialize(message="Must provide either a min or max value for scaling")
      super message
    end
  end

  class CartridgeNotScalableException < Exception
    def initialize(message="Cartridge is not scalable")
      super message
    end
  end

  class ConnectionFailed < Exception
  end

  class SSHAuthenticationFailed < Exception
    def initialize(host, user)
      super "Authentication to server #{host} with user #{user} failed"
    end
  end

  class SSHConnectionRefused < ConnectionFailed
    def initialize(host, user)
      super "The server #{host} refused a connection with user #{user}.  The application may be unavailable.", 1
    end
  end

  class SSHCommandFailed < Exception
    def initialize(exit_status, message=nil)
      super message || "SSH command finished with exit status = #{exit_status}", 133
    end
  end

  class AdditionalStorageArgumentsException < Exception
    def initialize(message="Only one storage action can be performed at a time.")
      super message, 1
    end
  end

  class AdditionalStorageValueException < Exception
    def initialize(message="The amount format must be a number, optionally followed by 'GB' (ex.: 5GB)")
      super message, 1
    end
  end

  class AdditionalStorageRemoveException < Exception
    def initialize(message="The amount of additional storage to be removed exceeds the total amount in use. Add the -f flag to override.")
      super message, 1
    end
  end

  class ChangeMembersOnResourceNotSupported < Exception
    def initialize(message="You can only add or remove members on a domain.")
      super message, 1
    end
  end

  class MembersNotSupported < Exception
    def initialize(message="The server does not support adding or removing members.")
      super message, 1
    end
  end

  class UnsupportedError < Exception
    def initialize(message="This operation is not supported by the server.")
      super message, 1
    end
  end
  class NoPerGearOperations < UnsupportedError
    def initialize
      super "The server does not support operations on individual gears."
    end
  end
  class ServerAPINotSupportedException < UnsupportedError
    def initialize(min_version, current_version)
      super "The server does not support this command (requires #{min_version}, found #{current_version})."
    end
  end
  class OperationNotSupportedException < UnsupportedError; end

  class InvalidURIException < Exception
    def initialize(uri)
      super "Invalid URI specified: #{uri}"
    end
  end

  class InvalidSSHExecutableException < Exception
    def initialize(message="Invalid or missing SSH executable")
      super message
    end
  end

  class InvalidRsyncExecutableException < Exception
    def initialize(message="Invalid or missing Rsync executable")
      super message
    end
  end

  class FileOrPathNotFound < Exception
    def initialize(message="File, file path, or directory could not be found")
      super message
    end
  end
  
  class RemoteFileOrPathNotFound < FileOrPathNotFound
    def initialize(message="Remote File, file path, or directory could not be found")
      super message
    end
  end

  class ArgumentNotValid < Exception
    def initialize(message="Argument is not valid for this command")
      super message
    end
  end

  class NoDomainsForUser < Exception
    def initialize(message="In order to deploy applications, you must create a domain with 'rhc setup' or 'rhc create-domain'.")
      super message, 1
    end
  end
end
