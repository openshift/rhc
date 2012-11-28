require 'open4'

module RHC
  module GitHelpers
    def git_version
      @git_version ||= `git --version 2>&1`.strip #:nocov:
    end

    def has_git?
      @has_git ||= begin
          @git_version = nil
          git_version
          $?.success?
        rescue
          false
        end
    end

    def git_clone_application(app)
      repo_dir = options.repo || app.name

      debug "Pulling new repo down"
      git_clone_repo(app.git_url, repo_dir)

      debug "Configuring git repo"
      Dir.chdir(repo_dir) do |dir|
        git_config_set "rhc.app-uuid", app.uuid
      end

      true
    end

    # :nocov: These all call external binaries so test them in cucumber
    def git_config_get(key)
      config_get_cmd = "git config --get #{key}"
      debug "Running #{config_get_cmd}"
      uuid = %x[#{config_get_cmd}].strip
      debug "UUID = '#{uuid}'"
      uuid = nil if $?.exitstatus != 0 or uuid.empty?

      uuid
    end

    def git_config_set(key, value)
      unset_cmd = "git config --unset-all #{key}"
      config_cmd = "git config --add #{key} #{value}"
      debug "Adding #{key} = #{value} to git config"
      commands = [unset_cmd, config_cmd]
      commands.each do |cmd|
        debug "Running #{cmd} 2>&1"
        output = %x[#{cmd} 2>&1]
        raise RHC::GitException, "Error while adding config values to git - #{output}" unless output.empty?
      end
    end
    # :nocov:

    def git_clone_repo(git_url, repo_dir)
      # quote the repo to avoid input injection risk
      destination = (repo_dir ? " \"#{repo_dir}\"" : "")
      cmd = "git clone #{git_url}#{destination}"
      debug "Running #{cmd}"

      say "Calling 'git clone #{git_url}'"

      status, stdout, stderr = nil

      paragraph do
        if RHC::Helpers.windows?
          #:nocov: TODO: Test block
          system(cmd)
          status = $?.exitstatus
          #:nocov:
        else
          stdout, stderr = [$stdout, $stderr].map{ |t| RHC::Helpers::StringTee.new(t) }
          status = Open4.spawn(cmd, 'stdout' => stdout, 'stderr' => stderr, 'raise' => false)
          stdout, stderr = [stdout, stderr].map(&:string)
        end
      end

      if status != 0
        case stderr
        when /fatal: destination path '[^']*' already exists and is not an empty directory./
          raise RHC::GitDirectoryExists, "The directory you are cloning into already exists."
        else
          raise RHC::GitException, "Unable to clone your repository"
        end
      end

      success "Your application is now in '#{repo_dir}'"
    end
  end
end
