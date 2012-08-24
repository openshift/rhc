@account_required @domain_required @application_required
Feature: Existing Application Operations

  Background:
    Given the libra client tools
    And an existing php-5.3 application

  @stopped_application
  Scenario: Application Starting
    When the application is started
    Then the application should be accessible

  Scenario Outline: Running Application Commands
    When the application is <command>
    Then <what> should <status>

    Examples:
      | command   | what            | status |
      | stopped   | the application | not be accessible |
      | restarted | the application | be accessible |
      | snapshot  | the snapshot    | be found |
      | tidied    | it              | succeed |
      | shown     | it              | succeed |
      | destroyed | the application | not exist |

  Scenario: Cartridge Add
    When the mysql-5.1 cartridge is added
    Then the mysql-5.1 cartridge should be running
