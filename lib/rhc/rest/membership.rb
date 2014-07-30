module RHC::Rest
  module Membership
    class Member < Base

      define_attr :name, :login, :id, :type, :from, :role, :owner, :explicit_role

      def owner?
        !!owner
      end

      def admin?
        role == 'admin'
      end

      def editor?
        role == 'edit'
      end

      def viewer?
        role == 'view'
      end

      def team?
        type == 'team'
      end

      def name
        attributes['name'] || login
      end

      def type
        attributes['type'] || 'user'
      end

      def explicit_role?
        explicit_role.present?
      end

      def from
        Array(attributes['from'])
      end

      def grant_from?(type, id)
        from.detect {|f| f['type'] == type && f['id'] == id}
      end

       def teams(members)
        team_ids = from.inject([]) {|ids, f| ids << f['id'] if f['type'] == 'team'; ids }
        members.select {|m| m.team? && team_ids.include?(m.id) }
      end

      def to_s
        if name == login
          "#{login} (#{role})"
        elsif login
          "#{name} <#{login}> (#{role})"
        else
          "#{name} (#{role})"
        end
      end

      def <=>(other)
        [role_weight, type, name, id] <=> [other.role_weight, other.type, other.name, other.id]
      end

      def role_weight
        if owner?
          0
        else
          case role
          when 'admin' then 1
          when 'edit' then 2
          when 'view' then 3
          else 4
          end
        end
      end
    end

    def self.included(other)
    end

    def supports_members?
      supports? 'LIST_MEMBERS'
    end

    def supports_update_members?
      supports? 'UPDATE_MEMBERS'
    end

    def default_member_role
      'edit'
    end

    def members
      @members ||=
        if (members = attributes['members']).nil?
          debug "Getting all members for #{id}"
          raise RHC::MembersNotSupported unless supports_members?
          rest_method 'LIST_MEMBERS'
        else
          members.map{ |m| Member.new(m, client) }
        end
    end

    def compact_members
      arr = members.reject(&:owner?) rescue []
      if arr.length > 5
        arr = arr.sort_by(&:name)
        admin, arr = arr.partition(&:admin?)
        edit, arr = arr.partition(&:editor?)
        view, arr = arr.partition(&:viewer?)
        admin << "Admins" if admin.present?
        edit << "Editors" if edit.present?
        view << "Viewers" if view.present?
        arr.map!(&:to_s)
        admin.concat(edit).concat(view).concat(arr)
      elsif arr.present?
        arr.sort_by{ |m| [m.role_weight, m.name] }.join(', ')
      end
    end

    def update_members(members, options={})
      raise "Members must be an array" unless members.is_a?(Array)
      raise RHC::MembersNotSupported unless supports_members?
      raise RHC::ChangeMembersOnResourceNotSupported unless supports_update_members?
      @members = (attributes['members'] = rest_method('UPDATE_MEMBERS', {:members => members}, options))
    end

    def delete_members(options={})
      raise RHC::MembersNotSupported unless supports_members?
      rest_method "LIST_MEMBERS", nil, {:method => :delete}.merge(options)
    ensure
      @members = attributes['members'] = nil
    end

    def leave(options={})
      raise RHC::MembersNotSupported.new("The server does not support leaving this resource.") unless supports? 'LEAVE'
      rest_method "LEAVE", nil, options
    ensure
      @members = attributes['members'] = nil
    end

    def owner
      members.find(&:owner?)
    rescue RHC::MembersNotSupported
      nil
    end
  end
end