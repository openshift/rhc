@multiple_cartridge
Feature: Multiple Cartridge Tests
  Background:
    # These need to be handled differently because the background gets run after the hooks

  @init
  Scenario: Supporting Cartridge Added
    Given we have a running php-5.3 application with an embedded mysql-5.1 cartridge
    When the phpmyadmin-3.4 cartridge is added
    Then the phpmyadmin-3.4 cartridge should be running

  Scenario: Conflicting Cartridge Fails
    Then adding the postgresql-8.5 cartridge should fail

  Scenario: Cartridge Removed
    When the phpmyadmin-3.4 cartridge is removed
    When the mysql-5.1 cartridge is removed
    Then the phpmyadmin-3.4 cartridge should be removed
    Then the mysql-5.1 cartridge should be removed
