@single_cartridge
Feature: Single Cartridge Tests
  Background:
    Given we have an existing domain

  @init
  Scenario: Cartridge Add
    Given an existing or new php-5.3 application without an embedded cartridge
    When the mysql-5.1 cartridge is added
    Then the mysql-5.1 cartridge should be running

  Scenario Outline: Cartridge Commands
    When the <type> cartridge is <command>
    Then the <type> cartridge should be <status>

    Examples:
      | type            | command   | status  |
      | mysql-5.1       | stopped   | stopped |
      | mysql-5.1       | started   | running |
      | mysql-5.1       | restarted | running |
