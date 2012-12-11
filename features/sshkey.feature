@sshkey @client_tools_required
Feature: SSH key Management
As an OpenShift user, I want to manage SSH keys with 'rhc sshkey' commands.

  @sshkey_list @key1
  Scenario: SSH key is listed
    When a new SSH key "key1.pub" is added as "key1"
    And the existing keys are listed
    Then the output includes the key information

  @sshkey_show @key1
  Scenario: SSH key is shown individually
    When the key "key1" is shown
    Then the output includes the key information for "key1"

  @sshkey_show
  Scenario: Requested SSH key does not exist
    When the key "key2" is shown
    Then the command exits with status code 118

  @sshkey_add
  Scenario: SSH key is added successfully
    When a new SSH key "key1.pub" is added as "key1"
    And the key "key1" is shown
    Then the output includes the key information for "key1"
    And the command exits with status code 0

  @sshkey_add
  Scenario: invalid key name is given
    When a new SSH key "key1.pub" is added as "blah\\ss"
    Then the command exits with status code 117

  @sshkey_add
  Scenario: invalid SSH key is added
    When a new SSH key "key3.pub" is added as "key3"
    Then the command exits with status code 128

  @sshkey_add
  Scenario: a valid private SSH key is added
    When a new SSH key "key1" is added as "key1"
    Then the command exits with status code 128

  @sshkey_add @key1
  Scenario: SSH key with the same name already exists
    When a new SSH key "key2.pub" is added as "key1"
    Then the command exits with status code 120

  @sshkey_add
  Scenario: SSH key with the identical content already exists
    Given a new SSH key "key1.pub" is added as "key1"
    And a new SSH key "key1.pub" is added as "key2"
    Then the command exits with status code 121  

  @sshkey_remove @key1
  Scenario: SSH key is deleted successfully
    When the key "key1" is removed
    And the key "key1" is shown
    Then the output does not include the key information for "key1"

  @sshkey_remove
  Scenario: SSH key requested to be deleted does not exist
    When the key "key1" is removed
    Then the command exits with status code 118
