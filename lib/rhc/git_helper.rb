require 'open3'

module RHC
  module GitHelpers
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

      exitstatus = nil
      err = nil
      paragraph do
        Open3.popen3(clone_cmd) do |stdin, stdout, stderr, wait_thr|
          stdin.close
          say stdout.read
          err = stderr.read
          exitstatus = wait_thr.value.exitstatus
        end
        say "done"
      end

      raise RHC::GitException, "Error in git clone - #{err}" if exitstatus != 0
    end
  end
end
