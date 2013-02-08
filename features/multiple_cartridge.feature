@multiple_cartridge @domain_required @clean
Feature: Multiple Cartridge Tests

  @init
  Scenario Outline: Supporting Cartridge Added
    Given an existing or new <php_version> application with an embedded mysql-5.1 cartridge
    When the phpmyadmin-3.4 cartridge is added
    Then the phpmyadmin-3.4 cartridge should be running

    @fedora-only
    Scenario: Fedora 18
      | php_version |
      | php-5.4     |

    @rhel-only
    Scenario: RHEL
      | php_version |
      | php-5.3     |


  Scenario: Conflicting Cartridge Fails
    Then adding the postgresql-8.5 cartridge should fail

  Scenario: Cartridge Removed
    When the phpmyadmin-3.4 cartridge is removed
    When the mysql-5.1 cartridge is removed
    Then the phpmyadmin-3.4 cartridge should be removed
    Then the mysql-5.1 cartridge should be removed
