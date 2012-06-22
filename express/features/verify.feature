Feature: Client Integration Tests
  Scenario: Setup Wizard
    Given the libra client tools
    When the setup wizard is run
    Then the client tools should be setup

  Scenario: Domain Creation
    Given the libra client tools
    When a new domain is needed and created
    Then the domain should be reserved

  Scenario: Application Creation
    Given the libra client tools
    When 1 php-5.3 applications are created
    Then the applications should be accessible

  Scenario: Application Stopping
    Given the libra client tools
    And an existing php-5.3 application
    When the application is stopped
    Then the application should not be accessible

  Scenario: Application Starting
    Given the libra client tools
    And an existing php-5.3 application
    When the application is started
    Then the application should be accessible

  Scenario: Application Restarting
    Given the libra client tools
    And an existing php-5.3 application
    When the application is restarted
    Then the application should be accessible

  Scenario: Application Snapshot
    Given the libra client tools
    And an existing php-5.3 application
    When the application is snapshot
    Then the snapshot should be found

  Scenario: Application Tidy
    Given the libra client tools
    And an existing php-5.3 application
    When the application is tidied
    Then it should succeed

  Scenario: Application Destroy
    Given the libra client tools
    And an existing php-5.3 application
    When the application is destroyed
    Then the application should not be accessible
