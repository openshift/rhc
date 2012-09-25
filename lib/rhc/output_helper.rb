module RHC
  module OutputHelpers
    def say_app_info(app)
      header "%s @ %s" % [app.name, app.app_url]
      say "Created: #{date(app.creation_time)}"
      say "   UUID: #{app.uuid}"
      say "Git URL: #{app.git_url}" if app.git_url
      say "SSH URL: #{app.ssh_url}" if app.ssh_url
      say "Aliases: #{app.aliases.join(', ')}" if app.aliases and not app.aliases.empty?
      carts = app.cartridges
      if carts.present?
        say "\nCartridges:"
        carts.each do |c|
          connection_url = c.property(:cart_data, :connection_url) || c.property(:cart_data, :job_url) || c.property(:cart_data, :monitoring_url)
          value = connection_url ? " - #{connection_url['value']}".rstrip : ""
          say "  #{c.name}#{value}"
        end
      else
        say "Cartridges: none"
      end
    end

    # Issues collector collects a set of recoverable issues and steps to fix them
    # for output at the end of a complex command
    def add_issue(reason, commands_header, *commands)
      @issues ||= []
      issue = {:reason => reason,
               :commands_header => commands_header,
               :commands => commands}
      @issues << issue
    end

    def format_issues(indent)
      return nil unless issues?

      indentation = " " * indent
      reasons = ""
      steps = ""

      @issues.each_with_index do |issue, i|
        reasons << "#{indentation}#{i+1}. #{issue[:reason].strip}\n"
        steps << "#{indentation}#{i+1}. #{issue[:commands_header].strip}\n"
        issue[:commands].each { |cmd| steps << "#{indentation}  $ #{cmd}\n" }
      end

      [reasons, steps]
    end

    def issues?
      not @issues.nil?
    end
  end
end
