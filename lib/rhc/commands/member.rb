require 'rhc/commands/base'

module RHC::Commands
  class Member < Base
    summary "Manage membership on domains"
    syntax "<action>"
    description <<-DESC
      Teams of developers can collaborate on applications by adding people to
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
    syntax "<domain_or_app_name> [-n DOMAIN_NAME] [-a APP_NAME]"
    description <<-DESC
      Show the existing members of a domain or application - you can pass the name
      of your domain with '-n', the name of your application with '-a', or combine
      them in the first argument to the command like:

        rhc members <domain_name>/[<app_name>]

      The owner is always listed first.  To see the unique ID of members, pass
      '--ids'.
      DESC
    option ['--ids'], "Display the IDs of each member", :optional => true
    takes_application_or_domain :argument => true
    alias_action :members, :root_command => true
    def list(path)
      target = find_app_or_domain(path)

      members = target.members
      show_name = members.any?{ |m| m.name && m.name != m.login }
      explicit_members = members.select(&:explicit_role?).sort

      say table((explicit_members).map do |member|
        [
          ((member.name || "") if show_name),
          (member.team? ? members.select {|m| m.grant_from?('team', member.id)}.map{|m| m.login || m.name}.join(' ') : member.login || ""),
          role_description(member, member.teams(members).present?),
          (member.id if options.ids),
          member.type
        ].compact
      end, :header => [('Name' if show_name), 'Login', 'Role', ("ID" if options.ids), "Type"].compact)

      0
    end

    summary "Add a member on a domain"
    syntax "<login> [<login>...] [-n DOMAIN_NAME] [--role view|edit|admin] [--ids] [--type team|user] [--global]"
    description <<-DESC
      Adds members on a domain by passing one or more user login, team name
      or ids for other people or teams on OpenShift.  The login and ID values for each
      account are displayed in 'rhc account'. To change the role for a user or team, 
      use the 'rhc member update' command.

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
          Gives the team with name 'team1' admin access on mydomain

      DESC
    takes_domain
    option ['--ids'], "Treat the arguments as a list of IDs", :optional => true
    option ['-r', '--role ROLE'], "The role to give to each member - view, edit, or admin (default 'edit')", :type => Role, :optional => true
    option ['--type TYPE'], "Type of argument(s) being passed. Accepted values are either 'team' or 'user' (default).", :optional => true
    option ['--global'], "Use global-scoped teams. Must be used with '--type team'.", :optional => true
    argument :members, "A list of members (user logins or team names) to add.  Pass --ids to treat this as a list of IDs.", [], :type => :list
    def add(members)
      target = find_domain
      role = options.role || 'edit'
      type = options.__hash__[:type] || 'user'
      global = !!options.global

      raise ArgumentError, 'You must pass one or more logins/names or ids to this command' unless members.present?
      raise ArgumentError, "The --global option can only be used with '--type team'." if global && !team?(type)
      
      say "Adding #{pluralize(members.length, role_name(role))} to #{target.class.model_name.downcase} ... "
      
      members = search_teams(members, global).map{|member| member.id} if team?(type) && !options.ids
      target.update_members(changes_for(members, role, type))

      success "done"

      0
    end

    summary "Update a member on a domain"
    syntax "<login> [<login>...] --role view|edit|admin [-n DOMAIN_NAME] [--ids] [--type team|user]"
    description <<-DESC
      Updates existing members on a domain by passing one or more user login, team name
      or ids for other people or teams on OpenShift.  You can use the 'rhc members' command
      to list the existing members of your domain. You cannot change the role of
      the owner.

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
          Changes the member with login 'bob@example.com' to 'admin' rols on mydomain

        rhc update-member team1 --type team --role admin -n mydomain
          Updated the team member with name 'team1' to the 'admin' role on mydomain

      DESC
    takes_domain
    option ['--ids'], "Treat the arguments as a list of IDs", :optional => true
    option ['-r', '--role ROLE'], "The role to give to each member - view, edit, or admin (default 'edit')", :type => Role, :optional => true
    option ['--type TYPE'], "Type of argument(s) being passed. Accepted values are either 'team' or 'user' (default).", :optional => true
    argument :members, "A list of members (user logins or team names) to update.  Pass --ids to treat this as a list of IDs.", [], :type => :list
    def update(members)
      target = find_domain
      role = options.role || 'edit'
      type = options.__hash__[:type] || 'user'

      raise ArgumentError, 'You must pass one or more logins/names or ids to this command' unless members.present?
      
      say "Updating #{pluralize(members.length, role_name(role))} to #{target.class.model_name.downcase} ... "
      
      members = filter_members(target.members, members).map{|member| member.id} if team?(type) && !options.ids
      target.update_members(changes_for(members, role, type))

      success "done"

      0
    end

    summary "Remove a member from a domain"
    syntax "<login> [<login>...] [-n DOMAIN_NAME] [--ids]"
    description <<-DESC
      Remove members on a domain by passing one or more login or ids for each
      member you wish to remove.  View the list of existing members with
      'rhc members <domain_name>'.

      Pass '--all' to remove all but the owner from the domain.
      DESC
    takes_domain
    option ['--ids'], "Treat the arguments as a list of IDs"
    option ['--all'], "Remove all members from this domain."
    option ['--type TYPE'], "Type of argument(s) being passed. Accepted values are either 'team' or 'user' (default).", :optional => true
    argument :members, "Member logins to remove from the domain.  Pass --ids to treat this as a list of IDs.", [], :type => :list
    def remove(members)
      target = find_domain
      type = options.__hash__[:type] || 'user'

      if options.all
        say "Removing all members from #{target.class.model_name.downcase} ... "
        target.delete_members
        success "done"

      else
        raise ArgumentError, 'You must pass one or more logins or ids to this command' unless members.present?

        say "Removing #{pluralize(members.length, 'member')} from #{target.class.model_name.downcase} ... "

        members = filter_members(target.members, members).map{|member| member.id} if team?(type) && !options.ids
        target.update_members(changes_for(members, 'none', type))

        success "done"
      end

      0
    end

    protected
      def changes_for(members, role, type)
        members.map do |m|
          h = {:role => role, :type => type}
          h[options.ids ||  team?(type) ? :id : :login] = m
          h
        end
      end

      def team?(member_type)
        member_type =~ /^team$/i
      end

      def search_teams(team_names, global=false)
        r = []
        team_names.each do |team_name|
          teams_for_name = 
            global ? 
              rest_client.search_teams(team_name, global) : 
              rest_client.search_owned_teams(team_name)

          if teams_for_name.empty?
            raise RHC::TeamNotFoundException.new("No #{global ? 'global ' : ''}team with name '#{team_name}' found.")

          elsif teams_for_name.length > 1
            exact_matches = teams_for_name.select{|t| t.name =~ /^#{team_name}$/i}

            if exact_matches.empty?
              raise RHC::TeamNotFoundException.new("No #{global ? 'global ' : ''}team found with exact name '#{team_name}', " +
                "did you mean one of the following: #{teams_for_name.map{|t| t.name}.join(', ')}?")

            elsif exact_matches.length == 1
              r << exact_matches.first

            else
              raise RHC::TeamNotFoundException.new("There are more than one team with name '#{team_name}'. " +
                "Please use the --ids flag and specify the exact id of the team you want to manage.")
            end

          else
            r << teams_for_name
          end
        end
        r.flatten
      end

      def filter_members(members, names)
        r = []
        names.each do |name|
          exact_matches = members.select{|member| member.name =~ /^#{name}$/i}

          if exact_matches.empty?
            raise RHC::MemberNotFoundException.new("No member found with name '#{name}'.")

          elsif exact_matches.length == 1
            r << exact_matches.first

          else
            raise RHC::MemberNotFoundException.new("There are more than one member with name '#{name}'. " +
              "Please use the --ids flag and specify the exact id of the member you want to manage.")
          end
        end
        r.flatten
      end

      def role_description(member, on_team=false)
        if member.owner?
          "#{member.role} (owner)"
        elsif on_team
          "#{member.role} (+ team role)"
        else 
          member.role
        end
      end
  end
end
