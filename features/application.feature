@application
Feature: Application Operations

  Background:
    Given we have an existing domain

  @init
  Scenario: Application Creation
    When a php-5.3 application is created
    Then the application should be accessible

  Scenario Outline: Running Application Commands
    When the application is <command>
    Then <what> should <status>

    Examples:
      | command   | what            | status |
      | stopped   | the application | not be accessible |
      | started   | the application | be accessible |
      | restarted | the application | be accessible |
      | snapshot  | the snapshot    | be found |
      | tidied    | it              | succeed |
      | shown     | it              | succeed |
      | destroyed | the application | not exist |
