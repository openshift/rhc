require 'spec_helper'
require 'direct_execution_helper'

describe "rhc member scenarios" do
  context "with an existing domain" do
    before(:all) do
      standard_config
      @domain = has_a_domain
    end

    let(:domain){ @domain }

    context "with no users" do
      before{ no_members(domain) }

      it "should not show members in the domain" do
        r = rhc 'show-domain', domain.name
        r.status.should == 0
        r.stdout.should_not match "Members:"
        r.stdout.should match "owned by #{domain.owner}"
      end

      it "should prevent leaving the domain for the owner" do
        r = rhc 'leave-domain', domain.name
        r.status.should_not == 1
        r.stdout.should match "Leaving domain.*You are the owner of this domain and cannot leave"
      end

      it "should add and remove a member" do
        user = other_users.keys.take(1).first
        r = rhc 'add-member', user, '-n', domain.name
        r.status.should == 0
        r.stdout.should match "Adding 1 editor to domain"
        r.stdout.should match "done"
        client.find_domain(domain.name).members.any?{ |m| m.id == other_users[user].id && m.editor? }.should be_true

        r = rhc 'show-domain', domain.name
        r.status.should == 0
        r.stdout.should match "Members:"
        r.stdout.should match "#{user} \\(edit\\)"

        r = rhc 'remove-member', user, '-n', domain.name
        r.status.should == 0
        r.stdout.should match "Removing 1 member from domain"
        client.find_domain(domain.name).members.none?{ |m| m.id == other_users[user].id }.should be_true
      end

      it "should add and remove two members" do
        user1, user2 = other_users.keys.take(2)
        r = rhc 'add-member', user1, user2, '-n', domain.name
        r.status.should == 0
        r.stdout.should match "Adding 2 editors to domain"
        r.stdout.should match "done"
        members = client.find_domain(domain.name).members
        members.any?{ |m| m.id == other_users[user1].id && m.editor? }.should be_true
        members.any?{ |m| m.id == other_users[user2].id && m.editor? }.should be_true

        r = rhc 'show-domain', domain.name
        r.status.should == 0
        r.stdout.should match "Members:"
        r.stdout.should match "#{user1} \\(edit\\)"
        r.stdout.should match "#{user2} \\(edit\\)"

        r = rhc 'remove-member', user1, user2, '-n', domain.name
        r.status.should == 0
        r.stdout.should match "Removing 2 members from domain"
        client.find_domain(domain.name).members.none?{ |m| m.id == other_users[user1].id }.should be_true
        client.find_domain(domain.name).members.none?{ |m| m.id == other_users[user2].id }.should be_true
      end

      it "should add a view and an admin member. and allow users to leave the domain" do
        user1, user2 = other_users.keys.take(2)

        r = rhc 'add-member', user1, '--role', 'admin', '-n', domain.name
        r.status.should == 0
        r.stdout.should match "Adding 1 administrator to domain"
        r.stdout.should match "done"
        client.find_domain(domain.name).members.any?{ |m| m.id == other_users[user1].id && m.admin? }.should be_true

        r = rhc 'add-member', user2, '--role', 'view', '-n', domain.name
        r.status.should == 0
        r.stdout.should match "Adding 1 viewer to domain"
        r.stdout.should match "done"
        client.find_domain(domain.name).members.any?{ |m| m.id == other_users[user2].id && m.viewer? }.should be_true

        r = rhc 'show-domain', domain.name
        r.status.should == 0
        r.stdout.should match "Members:"
        r.stdout.should match "#{user1} \\(admin\\)"
        r.stdout.should match "#{user2} \\(view\\)"

        r = rhc 'leave-domain', domain.name, :as => other_users[user2]
        r.status.should == 0
        r.stdout.should match "Leaving domain.*done"
      end

      it "should remove all non owners" do
        user1, user2 = other_users.keys.take(2)
        r = rhc 'add-member', user1, user2, '-n', domain.name
        r.status.should == 0
        r.stdout.should match "Adding 2 editors to domain"
        r.stdout.should match "done"
        members = client.find_domain(domain.name).members
        members.any?{ |m| m.id == other_users[user1].id && m.editor? }.should be_true
        members.any?{ |m| m.id == other_users[user2].id && m.editor? }.should be_true

        r = rhc 'remove-member', domain.name, '--all'
        r.status.should == 0
        r.stdout.should match "Removing all members from domain.*done"
        members = client.find_domain(domain.name).members
        members.select(&:owner).should == members
      end

      it "should reject a non-existent user" do
        r = rhc 'add-member', 'not-a-user', '-n', domain.name
        r.status.should_not == 1
        r.stdout.should match "There is no account with login not-a-user."
        client.find_domain(domain.name).members.length.should == 1
      end

      it "should add a user by id" do
        user = other_users.values.take(1).first
        r = rhc 'add-member', user.id, '--ids', '-n', domain.name
        r.status.should == 0
        r.stdout.should match "Adding 1 editor to domain"
        r.stdout.should match "done"
        client.find_domain(domain.name).members.any?{ |m| m.id == user.id && m.editor? }.should be_true
      end
    end
  end
end