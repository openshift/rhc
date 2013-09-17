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
      def name
        attributes['name'] || login
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
      def role_weight
        case role
        when 'admin' then 0
        when 'edit' then 1
        when 'view' then 2
        else 3
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
      arr = members.reject(&:owner?)
      if arr.length > 5
        arr.sort_by!(&:name)
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
      rest_method 'UPDATE_MEMBERS', {:members => members}, options
    end

    def delete_members(options={})
      raise RHC::MembersNotSupported unless supports_members?
      rest_method "LIST_MEMBERS", nil, {:method => :delete}.merge(options)
    ensure
      @members = attributes['members'] = nil
    end

    def owner
      if o = Array(attribute(:members)).find{ |m| m['owner'] == true }
        o['name']
      end
    end
  end
end