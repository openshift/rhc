require 'rhc/commands/base'

module RHC::Commands
  class Team < Base
    summary "Create or delete a team"
    syntax "<action>"
    description <<-DESC
      People who typically share the same role can be added to a team. The team can
      then be added as a member of a domain, and all of the people in the team will
      inherit the team's role on the domain.

      If a person is a member of multiple teams which are members of a domain, or
      is also added as a domain member individually, their effective role is the 
      higher of their individual role or their teams' roles on the domain.

      To create your first team, run 'rhc create-team'.

      To add members to an existing team, use the 'rhc add-member' command.

      To list members of an existing team, use the 'rhc members' command.
      DESC
    default_action :help

    summary "Create a new team"
    syntax "<team_name>"
    description <<-DESC
      People who typically share the same role can be added to a team. The team can
      then be added as a member of a domain, and all of the people in the team will
      inherit the team's role on the domain.

      If a person is a member of multiple teams which are members of a domain, or
      is also added as a domain member individually, their effective role is the 
      higher of their individual role or their teams' roles on the domain.
      DESC
    argument :team_name, "New team name (min 2 chars, max 250 chars)", ["-t", "--team-name NAME"]
    def create(name)
      say "Creating team '#{name}' ... "
      rest_client.add_team(name)
      success "done"

      info "You may now add team members using the 'rhc add-member' command"

      0
    end

    summary "Display a team and its members"
    syntax "<team_name>"
    takes_team :argument => true
    def show(_)
      team = find_team

      display_team(team, true)

      0
    end

    summary "Display all teams you are a member of"
    option ['--mine'], "Display only teams you own"
    alias_action :teams, :root_command => true
    def list
      teams = rest_client.send(options.mine ? :owned_teams : :teams, {:include => "members"})

      teams.each do |t|
        display_team(t, true)
      end

      if options.mine
        success "You have #{pluralize(teams.length, 'team')}."
      else
        success "You are a member of #{pluralize(teams.length, 'team')}."
      end

      0
    end

    summary "Delete a team"
    syntax "<team_name>"
    takes_team :argument => true
    def delete(_)
      team = find_team(:owned => true)

      say "Deleting team '#{team.name}' ... "
      team.destroy
      success "deleted"

      0
    end

    summary "Leave a team (remove your membership)"
    syntax "<team_name> [-t TEAM_NAME] [--team-id TEAM_ID]"
    takes_team :argument => true
    def leave(_)
      team = find_team

      say "Leaving team ... "
      result = team.leave
      success "done"
      result.messages.each{ |s| paragraph{ say s } }

      0
    end
  end
end
