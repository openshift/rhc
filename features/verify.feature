Feature: Client Integration Tests
  @init
  Scenario: Setup Wizard
    Given the libra client tools
    When the setup wizard is run
    Then the client tools should be setup

  @init
  Scenario: Domain Creation
    Given the libra client tools
    When a new domain is needed and created
    Then the domain should be reserved

  @init
  Scenario: Domain Creation for Apps
    Given the libra client tools
    When a new domain is needed and created
    Then the domain should be reserved

  Scenario: Application Creation
    Given the libra client tools
    When 1 php-5.3 applications are created
    Then the applications should be accessible

  Scenario: Cartridge Stop
    Given the libra client tools
    And an existing php-5.3 application with an embedded mysql-5.1 cartridge
    When the mysql-5.1 cartridge is stopped
    Then the mysql-5.1 cartridge should be stopped

  Scenario: Cartridge Start
    Given the libra client tools
    And an existing php-5.3 application with an embedded mysql-5.1 cartridge
    When the mysql-5.1 cartridge is started
    Then the mysql-5.1 cartridge should be running

  Scenario: Cartridge Restart
    Given the libra client tools
    And an existing php-5.3 application with an embedded mysql-5.1 cartridge
    When the mysql-5.1 cartridge is restarted
    Then the mysql-5.1 cartridge should be running

  Scenario: Supporting Cartridge Added
    Given the libra client tools
    And an existing php-5.3 application with an embedded mysql-5.1 cartridge
    When the phpmyadmin-3.4 cartridge is added
    Then the phpmyadmin-3.4 cartridge should be running

  Scenario: Conflicting Cartridge Fails
    Given the libra client tools
    And an existing php-5.3 application with embedded mysql-5.1 and phpmyadmin-3.4 cartridges
    Then adding the postgresql-8.5 cartridge should fail

  Scenario: Cartridge Removed
    Given the libra client tools
    And an existing php-5.3 application with embedded mysql-5.1 and phpmyadmin-3.4 cartridges
    When the phpmyadmin-3.4 cartridge is removed
    When the mysql-5.1 cartridge is removed
    Then the phpmyadmin-3.4 cartridge should be removed
    Then the mysql-5.1 cartridge should be removed

  Scenario: Add Alias
  Scenario: Remove Alias


  @init
  Scenario: Template Creation
  Scenario: Domain Changed
  Scenario: Template Deleted
  Scenario: Domain Changed Again
  Scenario: Domain Deleted

  @init
  Scenario: Key Added
  Scenario: Additional Key Added
  Scenario: Default Key Deleted
  Scenario: Key Overwritten
  Scenario: Key Deleted

  @init
  Scenario: Get Server Status
