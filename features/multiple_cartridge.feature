@multiple_cartridge
Feature: Multiple Cartridge Tests
  Background:
    Given we have a running php-5.3 application with an embedded mysql-5.1 cartridge

  @init
  Scenario: Supporting Cartridge Added
    When the phpmyadmin-3.4 cartridge is added
    Then the phpmyadmin-3.4 cartridge should be running

  Scenario: Conflicting Cartridge Fails
    Then adding the postgresql-8.5 cartridge should fail

  Scenario: Cartridge Removed
    When the phpmyadmin-3.4 cartridge is removed
    When the mysql-5.1 cartridge is removed
    Then the phpmyadmin-3.4 cartridge should be removed
    Then the mysql-5.1 cartridge should be removed
