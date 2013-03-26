@multiple_cartridge @domain_required @clean
Feature: Multiple Cartridge Tests

  @init
  Scenario: Supporting Cartridge Added
    Given an existing or new php application with an embedded mysql cartridge
    When the phpmyadmin cartridge is added
    Then the phpmyadmin cartridge should be running

  @not-origin
  Scenario: Conflicting Cartridge Fails
    Then adding the postgresql cartridge should fail

  Scenario: Cartridge Removed
    When the phpmyadmin cartridge is removed
    When the mysql cartridge is removed
    Then the phpmyadmin cartridge should be removed
    Then the mysql cartridge should be removed