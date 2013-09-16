require 'rhc/commands/base'

module RHC::Commands
  class Member < Base
    summary "Manage membership on domains"
    syntax "<action>"
    description <<-DESC
      Adding someone as a member on your domain will allow you to collaborate
      on applications.

      DESC

    summary "List members of a domain or application"
    syntax "<domain_or_app_path> [-n DOMAIN_NAME] [-a APP_NAME]"
    takes_application_or_domain :argument => true
    def list(path)
      target = find_app_or_domain(path)
      say table(target.members.map{ |m| [m.name, m.role, m.owner, m.id] }, :header => ['Name', 'Role', 'Owner?', 'ID'])

      0
    end

    summary "Add a collaborator to a domain"
    syntax "[-n DOMAIN_NAME]"
    takes_application_or_domain
    option ['--ids'], "Treat the arguments as a list of IDs", :optional => true
    option ['-r', '--role ROLE'], "The role to give to each member - view, edit, or admin (default 'edit')", :option_type => Role, :optional => true
    argument :members, "A list of members logins to add.  Pass --ids to treat this as a list of IDs.", [], :arg_type => :list
    def add(members)
      target = find_app_or_domain
      role = options.role || 'edit'
      raise ArgumentError, 'You must pass one or more logins or ids to this command' unless members.present?
      say "Adding #{pluralize(members.length, role_name(role))} to #{target.class.model_name.downcase} ... "
      target.update_members(changes_for(members, role))
      success "done"

      0
    end

    summary "Remove a member from a domain"
    syntax "<domain_or_app_path> [-n DOMAIN_NAME]"
    takes_application_or_domain
    option ['--ids'], "Treat the arguments as a list of IDs", :optional => true
    argument :members, "Member logins to remove from the domain.  Pass --ids to treat this as a list of IDs.", [], :arg_type => :list
    def remove(members)
      target = find_app_or_domain
      raise ArgumentError, 'You must pass one or more logins or ids to this command' unless members.present?
      say "Removing #{pluralize(members.length, 'member')} from #{target.class.model_name.downcase} ... "
      target.update_members(changes_for(members, 'none'))
      success "done"

      0
    end

    protected
      def changes_for(members, role)
        members.map do |m|
          h = {:role => role}
          h[options.ids ? :id : :login] = m
          h
        end
      end
  end
end