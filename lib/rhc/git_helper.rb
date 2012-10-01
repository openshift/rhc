require 'open4'

module RHC
  module GitHelpers
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
      cmd = "(#{unset_cmd}; #{config_cmd})"

      debug "Running #{cmd} 2>&1"
      debug "Adding #{key} = #{value} to git config"

      output = %x[#{cmd} 2>&1]
      raise RHC::GitException, "Error while adding config values to git - #{output}" unless output.empty?
    end

    def git_clone_repo(git_url, repo_dir)
      # quote the repo to avoid input injection risk
      repo_dir = (repo_dir ? " \"#{repo_dir}\"" : "")
      clone_cmd = "git clone #{git_url}#{repo_dir}"
      debug "Running #{clone_cmd}"

      err = nil
      if RHC::Helpers.windows?
        # windows does not support Open4 so redirect stderr to stdin
        # and print the whole output which is not as clean
        output = %x[#{clone_cmd} 2>&1]
        if $?.exitstatus != 0
          err = output
        else
          say output
        end
      else
        paragraph do
          Open4.popen4(clone_cmd) do |pid, stdin, stdout, stderr|
            stdin.close
            say stdout.read
            err = stderr.read
          end
          say "done"
        end
      end

      raise RHC::GitException, "Error in git clone - #{err}" if $?.exitstatus != 0
    end
    # :nocov:
  end
end
