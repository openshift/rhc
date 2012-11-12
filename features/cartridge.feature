@single_cartridge @domain_required
Feature: Single Cartridge Tests

  # Need to keep these outlines duplicated until we update cucumber to allow tagged examples

  @init
  Scenario Outline: Cartridge Commands
    When the <type> cartridge is <command>
    Then the <type> cartridge should be <status>

    Examples:
      | type            | command   | status  |
      | mysql-5.1       | added     | running |

  Scenario Outline: Cartridge Commands
    Given we have a <state> mysql-5.1 cartridge
    When the mysql-5.1 cartridge is <command>
    Then the mysql-5.1 cartridge should be <status>

    Examples:
      | state   | command   | status  |
      | running | restarted | running |
      | running | stopped   | stopped |
      | stopped | started   | running |

  Scenario Outline: Cartridge List
    When we list cartridges
    Then the list should contain the cartridge <cart> with display name "<name>"

    Examples:
      | cart        | name          |
      | php-5.3     | PHP 5.3       |
      | mongodb-2.2 | MongoDB NoSQL |
      | cron-1.4    | Cron 1.4      |
