require 'rhc/commands/base'

module RHC::Commands
  class Member < Base
    summary "Manage membership on domains"
    syntax "<action>"
    description <<-DESC
      Developers can collaborate on applications by adding people or teams to
      domains as members: each member has a role (admin, editor, or viewer),
      and those roles determine what the user can do with the domain and the
      applications contained within.

      Roles:

        view  - able to see information about the domain and its apps, but not make any changes
        edit  - create, update, and delete applications, and has Git and SSH access
        admin - can update membership of a domain

      The default role granted to members when added is 'edit' - use the '--role'
      argument to use another.  When adding and removing members, you can use their
      'login' value (typically their email or a short unique name for them) or their
      'id'.  Both login and ID are visible via the 'rhc account' command.

      To see existing members of a domain or application, use:

        rhc members -n <domain_name> [-a <app_name>]

      To change the role for a user, simply call the add-member command with the new role. You
      cannot change the role of the owner.
      DESC
    syntax "<action>"
    default_action :help

    summary "List members of a domain or application"
    syntax "<domain_or_app_name> [-n DOMAIN_NAME] [-a APP_NAME] [--all]"
    description <<-DESC
      Show the existing members of a domain or application - you can pass the name
      of your domain with '-n', the name of your application with '-a', or combine
      them in the first argument to the command like:

        rhc members <domain_name>/[<app_name>]

      The owner is always listed first.  To see the unique ID of members, pass
      '--ids'.
      DESC
    option ['--ids'], "Display the IDs of each member", :optional => true
    option ['--all'], "Display all members, including the owner and all team members", :optional => true
    takes_application_or_domain :argument => true
    alias_action :members, :root_command => true
    def list(path)
      target = find_app_or_domain(path)

      members = target.members
      if options.all
        show_members = members.sort
      else
        show_members = members.select(&:explicit_role?).sort
      end
      show_name = show_members.any?{ |m| m.name.presence && m.name != m.login }
      show_login = show_members.any?{ |m| m.login.presence }
      
      if show_members.present?
        say table(show_members.map do |member|
          [
            ((member.name || "") if show_name),
            ((member.login || "") if show_login),
            role_description(member, member.teams(members)),
            (member.id if options.ids),
            member.type
          ].compact
        end, :header => [
          ('Name' if show_name),
          ('Login' if show_login),
          'Role',
          ("ID" if options.ids),
          "Type"
        ].compact)
      else
        info "The #{target.class.model_name.downcase} #{target.name} does not have any members."
      end

      if show_members.any?(&:team?) && show_members.count < members.count
        paragraph do
          info "Pass --all to display all members, including the owner and all team members."
        end
      end

      0
    end

    summary "Add a member on a domain"
    syntax "(<login>... | <team name>... | <id>...) [-n DOMAIN_NAME] [--role view|edit|admin] [--ids] [--type user|team] [--global]"
    description <<-DESC
      Adds members on a domain by passing a user login, team name, or ID for each 
      member. The login and ID for each account are displayed in 'rhc account'.
      To change the role for an existing domain member, use the 'rhc member update'
      command.

      Roles
        view  - able to see information about the domain and its apps,
                but not make any changes
        edit  - create, update, and delete applications, and has Git
                and SSH access
        admin - can update membership of a domain

      The default role granted to members when added is 'edit' - use the '--role'
      argument for 'view' or 'admin'.

      Examples
        rhc add-member sally joe -n mydomain
          Gives the accounts with logins 'sally' and 'joe' edit access on mydomain

        rhc add-member bob@example.com --role admin -n mydomain
          Gives the account with login 'bob@example.com' admin access on mydomain

        rhc add-member team1 --type team --role admin -n mydomain
          Gives your team named 'team1' admin access on mydomain

      DESC
    takes_domain
    option ['--ids'], "Treat the arguments as a list of IDs", :optional => true
    option ['-r', '--role ROLE'], "The role to give to each member - view, edit, or admin (default is 'edit')", :type => Role, :optional => true
    option ['--type TYPE'], "Type of argument(s) being passed. Accepted values are either 'team' or 'user' (default is 'user').", :optional => true
    option ['--global'], "Use global-scoped teams. Must be used with '--type team'.", :optional => true
    argument :members, "A list of members (user logins, team names, or IDs) to add. Pass --ids to treat this as a list of IDs.", [], :type => :list
    def add(members)
      target = find_domain
      role = get_role_option(options)
      type = get_type_option(options)
      global = !!options.global

      raise ArgumentError, 'You must pass at least one user login, team name, or ID to this command.' unless members.present?
      raise ArgumentError, "The --global option can only be used with '--type team'." if global && !team?(type)
      
      say "Adding #{pluralize(members.length, role_name(role))} to #{target.class.model_name.downcase} ... "
      
      members = search_teams(members, global).map{|member| member.id} if team?(type) && !options.ids
      target.update_members(changes_for(members, role, type))

      success "done"

      0
    end

    summary "Update a member on a domain"
    syntax "(<login>... | <team name>... | <id>...) --role view|edit|admin [-n DOMAIN_NAME] [--ids] [--type user|team]"
    description <<-DESC
      Updates members on a domain by passing a user login, team name, or ID for 
      each member. You can use the 'rhc members' command to list the existing 
      members of your domain. You cannot change the role of the owner.

      Roles
        view  - able to see information about the domain and its apps,
                but not make any changes
        edit  - create, update, and delete applications, and has Git
                and SSH access
        admin - can update membership of a domain

      The default role granted to members when added is 'edit' - use the '--role'
      argument for 'view' or 'admin'.

      Examples
        rhc update-member bob@example.com --role view -n mydomain
          Adds or updates the member with login 'bob@example.com' to 'admin' role on mydomain

        rhc update-member team1 --type team --role admin -n mydomain
          Updates the team member with name 'team1' to the 'admin' role on mydomain

        rhc update-member team1_id --type team --role admin -n mydomain --ids
          Adds or updates the team with ID 'team1_id' to the 'admin' role on mydomain

      DESC
    takes_domain
    option ['--ids'], "Treat the arguments as a list of IDs", :optional => true
    option ['-r', '--role ROLE'], "The role to give to each member - view, edit, or admin (default is 'edit')", :type => Role, :optional => true
    option ['--type TYPE'], "Type of argument(s) being passed. Accepted values are either 'team' or 'user' (default is 'user').", :optional => true
    argument :members, "A list of members (user logins, team names, or IDs) to update.  Pass --ids to treat this as a list of IDs.", [], :type => :list
    def update(members)
      target = find_domain
      role = get_role_option(options)
      type = get_type_option(options)

      raise ArgumentError, 'You must pass at least one user login, team name, or ID to this command.' unless members.present?
      
      say "Updating #{pluralize(members.length, role_name(role))} to #{target.class.model_name.downcase} ... "
      
      members = search_team_members(target.members, members).map{|member| member.id} if team?(type) && !options.ids
      target.update_members(changes_for(members, role, type))

      success "done"

      0
    end

    summary "Remove a member from a domain"
    syntax "(<login>... | <team name>... | <id>...) [-n DOMAIN_NAME] [--ids] [--type user|team]"
    description <<-DESC
      Remove members from a domain by passing a user login, team name, or ID for each
      member you wish to remove.  View the list of existing members with
      'rhc members <domain_name>'.

      Pass '--all' to remove all but the owner from the domain.
      DESC
    takes_domain
    option ['--ids'], "Treat the arguments as a list of IDs"
    option ['--all'], "Remove all members from this domain."
    option ['--type TYPE'], "Type of argument(s) being passed. Accepted values are either 'team' or 'user' (default is 'user').", :optional => true
    argument :members, "A list of members (user logins, team names, or IDs) to remove from the domain.  Pass --ids to treat this as a list of IDs.", [], :type => :list
    def remove(members)
      target = find_domain
      type = get_type_option(options)

      if options.all
        say "Removing all members from #{target.class.model_name.downcase} ... "
        target.delete_members
        success "done"

      else
        raise ArgumentError, 'You must pass at least one user login, team name, or ID to this command.' unless members.present?

        say "Removing #{pluralize(members.length, 'member')} from #{target.class.model_name.downcase} ... "

        members = search_team_members(target.members, members).map{|member| member.id} if team?(type) && !options.ids
        target.update_members(changes_for(members, 'none', type))

        success "done"
      end

      0
    end

    protected
      def get_role_option(options, default_value='edit')
        options.role || default_value
      end

      def get_type_option(options, default_value='user')
        type = options.__hash__[:type]
        case type
        when 'team'
          type
        when 'user'
          type
        when nil
          default_value
        else
          raise ArgumentError, "The type '#{type}' is not valid. Type must be 'user' or 'team'."
        end
      end

      def changes_for(members, role, type)
        members.map do |m|
          h = {:role => role, :type => type}
          h[options.ids ||  team?(type) ? :id : :login] = m
          h
        end
      end

      def team?(type)
        type == 'team'
      end

      def search_teams(team_names, global=false)
        r = []
        team_names.each do |team_name|
          teams_for_name = 
            global ? 
              rest_client.search_teams(team_name, global) : 
              rest_client.search_owned_teams(team_name)

          team_for_name = nil
          suggestions = nil

          if (exact_matches = teams_for_name.select {|t| t.name == team_name }).present?
            if exact_matches.length == 1
              team_for_name = exact_matches.first
            else
              raise RHC::TeamNotFoundException.new("There is more than one team named '#{team_name}'. " +
                "Please use the --ids flag and specify the exact id of the team you want to manage.")
            end

          elsif (case_insensitive_matches = teams_for_name.select {|t| t.name =~ /^#{Regexp.escape(team_name)}$/i }).present?
            if case_insensitive_matches.length == 1
              team_for_name = case_insensitive_matches.first
            else
              suggestions = case_insensitive_matches
            end

          else
            suggestions = teams_for_name
          end


          if team_for_name
            r << team_for_name
          elsif suggestions.present?
            msg = global ? "No global team found with the name '#{team_name}'." : "You do not have a team named '#{team_name}'."
            raise RHC::TeamNotFoundException.new(msg + " Did you mean one of the following?\n#{suggestions[0..50].map(&:name).join(", ")}")
          else
            msg = global ? "No global team found with the name '#{team_name}'." : "You do not have a team named '#{team_name}'."
            raise RHC::TeamNotFoundException.new(msg)
          end

        end
        r.flatten
      end

      def search_team_members(members, names)
        r = []
        team_members = members.select(&:team?)
        names.each do |name|

          team_for_name = nil
          suggestions = nil

          if (exact_matches = team_members.select{|team| team.name == name }).present?
            if exact_matches.length == 1
              team_for_name = exact_matches.first
            else
              raise RHC::MemberNotFoundException.new("There is more than one team named '#{name}'. " +
                "Please use the --ids flag and specify the exact id of the team you want to manage.")
            end

          elsif (case_insensitive_matches = team_members.select{|team| team.name =~ /^#{Regexp.escape(name)}$/i}).present?
            if case_insensitive_matches.length == 1
              team_for_name = case_insensitive_matches.first
            else
              suggestions = case_insensitive_matches
            end

          else
            suggestions = team_members.select{|t| t.name =~ /#{Regexp.escape(name)}/i}
          end

          if team_for_name
            r << team_for_name
          elsif suggestions.present?
            raise RHC::TeamNotFoundException.new("No team found with the name '#{name}'. " +
              "Did you mean one of the following?\n#{suggestions[0..50].map(&:name).join(", ")}")
          else
            raise RHC::MemberNotFoundException.new("No team found with the name '#{name}'.")
          end

        end
        r.flatten
      end

      def role_description(member, teams=[])
        if member.owner?
          "#{member.role} (owner)"
        elsif member.explicit_role != member.role && teams.present? && (teams_with_role = teams.select{|t| t.role == member.role }).present?
          "#{member.role} (via #{teams_with_role.map(&:name).sort.join(', ')})"
        else
          member.role
        end
      end
  end
end
