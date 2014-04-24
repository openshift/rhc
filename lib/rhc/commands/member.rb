require 'rhc/commands/base'

module RHC::Commands
  class Member < Base
    summary "Manage membership on domains and teams"
    syntax "<action>"
    description <<-DESC
      Domain Membership
        Developers can collaborate on applications by adding people or teams to
        domains as members. Each member has a role (admin, edit, or view),
        and those roles determine what the user can do with the domain and the
        applications contained within.

        Domain Member Roles

          view  - able to see the domain and its apps, but not make any changes
          edit  - create, update, and delete applications, and has Git and SSH access
          admin - can update membership of a domain

        The default role granted to domain members is 'edit' - use the '--role' 
        argument to specify a different role. When adding and removing members, you 
        can use their 'login' value (typically their email or a short unique name for
        them), or their 'id'.  Both login and ID are visible via the 'rhc account' 
        command.

        To see existing members of a domain or application, use:

          rhc members -n DOMAIN_NAME [-a APP_NAME]

        To change the role for a domain member, simply call the update-member command 
        with the new role. You cannot change the role of the owner.

      Team Membership
        People who typically share the same role can be added to a team. The team can
        then be added as a member of a domain, and all of the people in the team will
        inherit the team's role on the domain.

        If a person is a member of multiple teams which are members of a domain, or
        is also added as a domain member individually, their effective role is the 
        higher of their individual role or their teams' roles on the domain.

        Team Member Roles
          view  - able to see information about the team and its members, and
                  has access to all domains the team is a member of

        To see existing members of a team, use:

          rhc members -t TEAM_NAME

      DESC
    syntax "<action>"
    default_action :help

    summary "List members of a domain, application, or team"
    syntax [
      "<domain_name>[/<app_name>] [--all]",
      "-n DOMAIN_NAME [--all]",
      "-n DOMAIN_NAME -a APP_NAME [--all]",
      nil,
      "-t TEAM_NAME"
    ]
    description <<-DESC
      Show the existing members of a domain, application, or team.

      To show the members of a domain or application, you can pass the name of your 
      domain with '-n', the name of your application with '-a', or combine them in
      the first argument to the command like:
        rhc members <domain_name>[/<app_name>]

      To show the members of a team, you can pass the name of the team with '-t':
        rhc members -t TEAM_NAME

      The owner is always listed first.  To see the unique ID of members, pass '--ids'.
      DESC
    option ['--ids'], "Display the IDs of each member", :optional => true
    option ['--all'], "Display all members, including members of teams", :optional => true
    takes_membership_container :argument => true
    alias_action :members, :root_command => true
    def list(_)
      target = find_membership_container

      members = target.members
      if options.all
        show_members = members.sort
      else
        show_members = members.select do |m| 
          if m.owner?
            true
          elsif m.explicit_role?
            true
          elsif m.from.any? {|f| f["type"] != "team" }
            true
          else
            false
          end
        end.sort
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

      if show_members.count < members.count
        paragraph do
          info "Pass --all to display all members, including members of teams."
        end
      end

      0
    end

    summary "Add a member to a domain or team"
    syntax [
      "-n DOMAIN_NAME [--role view|edit|admin] <login>...",
      "-n DOMAIN_NAME [--role view|edit|admin] <team_name>... --type team [--global]",
      "-n DOMAIN_NAME [--role view|edit|admin] <id>... --ids [--type user|team]",
      nil,
      "-t TEAM_NAME <login>...",
      "-t TEAM_NAME <id>... --ids",
    ]
    description <<-DESC
      Domain Membership
        Add members to a domain by passing a user login, team name, or ID for each 
        member. The login and ID for each account are displayed in 'rhc account'.
        To change the role for an existing domain member, use the 'rhc member update'
        command.

        Domain Member Roles
          view  - able to see information about the domain and its apps,
                  but not make any changes
          edit  - create, update, and delete applications, and has Git
                  and SSH access
          admin - can update membership of a domain

          The default role granted to domain members is 'edit'.
          Use the '--role' argument for 'view' or 'admin'.

      Team Membership
        Add users to a team by passing a user login, or ID for each member.

        Team Member Roles
          view  - able to see information about the team and its members, and
                  has access to all domains the team is a member of

      Examples
        rhc add-member sally joe -n mydomain
          Gives the accounts with logins 'sally' and 'joe' edit access on mydomain

        rhc add-member bob --role admin -n mydomain
          Gives the account with login 'bob' admin access on mydomain

        rhc add-member team1 --type team --role admin -n mydomain
          Gives your team named 'team1' admin access on mydomain

        rhc add-member steve -t team1
          Adds the account with login 'steve' as a member of your team named 'team1'
      DESC
    takes_membership_container :writable => true
    option ['--ids'], "Add member(s) by ID", :optional => true
    option ['-r', '--role ROLE'], "The role to give to each member - view, edit, or admin (default is 'edit' for domains, 'view' for teams)", :type => Role, :optional => true
    option ['--type TYPE'], "Type of member(s) being added - user or team (default is 'user').", :optional => true
    option ['--global'], "Add global-scoped teams as members. Must be used with '--type team'.", :optional => true
    argument :members, "A list of members (user logins, team names, or IDs) to add. Pass --ids to treat this as a list of IDs.", [], :type => :list
    def add(members)
      target = find_membership_container :writable => true

      role = get_role_option(options, target)
      type = get_type_option(options)
      global = !!options.global

      raise ArgumentError, 'You must pass at least one member to this command.' unless members.present?
      raise ArgumentError, "The --global option can only be used with '--type team'." if global && !team?(type)
      
      say "Adding #{pluralize(members.length, role_name(role))} to #{target.class.model_name.downcase} ... "
      
      members = search_teams(members, global).map{|member| member.id} if team?(type) && !options.ids
      target.update_members(changes_for(members, role, type))

      success "done"

      0
    end

    summary "Update a member on a domain"
    syntax [
      "-n DOMAIN_NAME --role view|edit|admin <login>...",
      "-n DOMAIN_NAME --role view|edit|admin <team_name>... --type team",
      "-n DOMAIN_NAME --role view|edit|admin <id>... --ids [--type user|team]",
    ]
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

      Examples
        rhc update-member -n mydomain --role view bob
          Adds or updates the user with login 'bob' to 'admin' role on mydomain

        rhc update-member -n mydomain --role admin team1 --type team
          Updates the team member with name 'team1' to the 'admin' role on mydomain

        rhc update-member -n mydomain --role admin team1_id --ids --type team
          Adds or updates the team with ID 'team1_id' to the 'admin' role on mydomain

      DESC
    takes_domain
    option ['--ids'], "Update member(s) by ID", :optional => true
    option ['-r', '--role ROLE'], "The role to give to each member - view, edit, or admin", :type => Role, :optional => false
    option ['--type TYPE'], "Type of member(s) being updated - user or team (default is 'user').", :optional => true
    argument :members, "A list of members (user logins, team names, or IDs) to update.  Pass --ids to treat this as a list of IDs.", [], :type => :list
    def update(members)
      target = find_domain
      role = get_role_option(options, target)
      type = get_type_option(options)

      raise ArgumentError, 'You must pass at least one member to this command.' unless members.present?
      
      say "Updating #{pluralize(members.length, role_name(role))} to #{target.class.model_name.downcase} ... "
      
      members = search_team_members(target.members, members).map{|member| member.id} if team?(type) && !options.ids
      target.update_members(changes_for(members, role, type))

      success "done"

      0
    end

    summary "Remove a member from a domain or team"
    syntax [
      "-n DOMAIN_NAME <login>...",
      "-n DOMAIN_NAME <team_name>... --type team",
      "-n DOMAIN_NAME <id>... --ids [--type user|team]",
      nil,
      "-t TEAM_NAME <login>...",
      "-t TEAM_NAME <id>... --ids",
    ]
    description <<-DESC
      Remove members from a domain by passing a user login, team name, or ID for each
      member you wish to remove.  View the list of existing members with
        rhc members -n DOMAIN_NAME

      Remove members from a team by passing a user login, or ID for each
      member you wish to remove.  View the list of existing members with
        rhc members -t TEAM_NAME

      Pass '--all' to remove all members but the owner.
      DESC
    takes_membership_container :writable => true
    option ['--ids'], "Remove member(s) by ID."
    option ['--all'], "Remove all members"
    option ['--type TYPE'], "Type of member(s) being removed - user or team (default is 'user').", :optional => true
    argument :members, "A list of members (user logins, team names, or IDs) to remove.  Pass --ids to treat this as a list of IDs.", [], :type => :list
    def remove(members)
      target = find_membership_container :writable => true
      type = get_type_option(options)

      if options.all
        say "Removing all members from #{target.class.model_name.downcase} ... "
        target.delete_members
        success "done"

      else
        raise ArgumentError, 'You must pass at least one member to this command.' unless members.present?

        say "Removing #{pluralize(members.length, 'member')} from #{target.class.model_name.downcase} ... "

        members = search_team_members(target.members, members).map{|member| member.id} if team?(type) && !options.ids
        target.update_members(changes_for(members, 'none', type))

        success "done"
      end

      0
    end

    protected
      def get_role_option(options, target)
        options.role || target.default_member_role
      end

      def get_type_option(options)
        type = options.__hash__[:type]
        type || 'user'
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
              raise RHC::MemberNotFoundException.new("There is more than one member team named '#{name}'. " +
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
            raise RHC::MemberNotFoundException.new("No member team found with the name '#{name}'. " +
              "Did you mean one of the following?\n#{suggestions[0..50].map(&:name).join(", ")}")
          else
            raise RHC::MemberNotFoundException.new("No member team found with the name '#{name}'.")
          end

        end
        r.flatten
      end

      def role_description(member, teams=[])
        if member.owner?
          "#{member.role} (owner)"
        elsif member.explicit_role != member.role && member.from.all? {|f| f['type'] == 'domain'}
          "#{member.role} (via domain)"
        elsif member.explicit_role != member.role && teams.present? && (teams_with_role = teams.select{|t| t.role == member.role }).present?
          "#{member.role} (via #{teams_with_role.map(&:name).sort.join(', ')})"
        else
          member.role
        end
      end
  end
end
