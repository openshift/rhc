module RHC::Rest
  module Membership
    class Member < Base
      define_attr :name, :id, :type, :from, :role, :owner, :explicit_role
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
          debug "Getting all members for #{name}"
          raise MembersNotSupported unless supports_membership?
          rest_method 'LIST_MEMBERS'
        else
          members.map{ |m| Member.new(m, client) }
        end
    end

    def update_members(members, options={})
      raise "Members must be an array" unless members.is_a?(Array)
      raise MembersNotSupported unless supports_members?
      raise RHC::ChangeMembersOnResourceNotSupported unless supports_update_members?
      rest_method 'UPDATE_MEMBERS', {:members => members}, options
    end

    def owner
      if o = Array(attribute(:members)).find{ |m| m['owner'] == true }
        o['name']
      end
    end
  end
end