@domain @client_tools_required
Feature: Existing Domain Operations

  @init
  Scenario: Domain Creation
    When a new domain is needed and created
    Then the domain should be reserved

  Scenario: Domain Update
    When domain is updated
    Then the domain should be reserved

  Scenario: Domain Show
    When rhc domain is run
    When rhc domain show is run
    Then the default domain action output should equal the show action output

  Scenario: Domain Create Fails
    When rhc domain create is called
    Then the domain command should fail with an exitcode of 128

  Scenario: Domain Delete
    When domain is deleted
    Then domains should be empty

