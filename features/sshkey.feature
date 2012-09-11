@sshkey @client_tools_required
Feature: SSH key Management
As an OpenShift user, I want to manage SSH keys with 'rhc sshkey' commands.

  @sshkey_list
  Scenario: SSH key is listed
    Given the SSH key "key1" already exists
    When 'rhc sshkey list' is run
    Then the output includes the key information
  
  @sshkey_show
  Scenario: SSH key is shown individually
    Given the SSH key "key1" already exists
    When 'rhc sshkey show "key1"' is run
    Then the output includes the key information for "key1"
  
  @sshkey_show
  Scenario: Requested SSH key does not exist
    Given the SSH key "key2" does not exist
    When 'rhc sshkey show "key2"' command is run
    Then the command exits with status code 118
  
  @sshkey_add
  Scenario: SSH key is added successfully
    Given the SSH key "key1" does not exist
    When a new SSH key "features/support/key1.pub" is added as "key1"
    Then the key "key1" should exist
    And the command exits with status code 0
  
  @sshkey_add
  Scenario: SSH key with the same name already exists
    Given the SSH key "key1" already exists
    When a new SSH key "features/support/key2.pub" is added as "key1"
    Then the command exits with status code 128
  
  @sshkey_add
  Scenario: SSH key with the identical content already exists
    Given an SSH key "key2" with the same content as "key1" exists
    And the SSH key "key1" does not exist
    When 'rhc sshkey add "key1" "features/support/key1.pub"' is run
    Then the command exits with status code 128
  
  @sshkey_update
  Scenario: 'update' subcommand is invoked
    When 'rhc sshkey update' is run
    Then the command exits with status code 1
    And the output includes deprecation warning
  
  @sshkey_remove
  Scenario: SSH key is deleted successfully
    When 'rhc sshkey remove "key1"' is run
    Then the SSH key "key1" is deleted
  
  @sshkey_remove
  Scenario: SSH key requested to be deleted does not exist
    Given the SSH key "key1" does not exist
    When 'rhc sshkey remove "key1"' is run
    Then the command exits with status code 118