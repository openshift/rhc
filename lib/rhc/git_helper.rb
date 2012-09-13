module RHC
  module GitHelpers
    def git_config_get(key)
      config_get_cmd = "git config --get #{key}"
      debug "Running #{config_get_cmd}"
      uuid = %x[#{get_uuid_cmd}].strip
      debug "UUID = '#{uuid}'"
      return nil if $?.exitstatus != 0 or uuid.empty?
    end

    def git_config_set(key, value)
      unset_cmd = "git config --unset-all #{key}"
      config_cmd = "git config --add #{key} #{value}"
      cmd = "(#{unset_cmd}; #{config_cmd})"

      debug "Running #{cmd} 2>&1"
      debug "Adding #{name} = #{value} to git config"

      output = %x[#{cmd} 2>&1]
      raise RHC::GitException, "Error while adding config values to git - #{output}" unless output.empty?
    end

    def git_clone_repo(git_url, repo_dir)
      say "Git gloning app at #{git_url} into directory #{repo_dir}"
      quiet = (@debug ? '' : '--quiet ')

      # quote the repo to avoid input injection risk
      repo_dir = (repo_dir ? " #{%q{options.repo}}" : "")
      clone_cmd = "git clone #{quiet} #{git_url}#{repo_dir}"
      debug "Running #{clone_cmd} 2>&1"

      output = %x[#{clone_cmd} 2>&1]

      raise RHC::GitException, "Error in git clone - #{output}" if $?.exitstatus != 0
    end
  end
end
