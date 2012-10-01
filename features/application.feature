@application @domain_required
Feature: Application Operations

  @init
  Scenario: Application Creation
    When a php-5.3 application is created
    Then the application should be accessible

  # The state in these examples should be able to be broken into before hooks when we update cucumber
  Scenario Outline: Running Application Commands
    Given we have a <state> application
    When the application is <command>
    Then <what> should <status>

    # Breaking these examples up so they can flow logically, but also be run individually
    Examples:
      | state   | command   | what            | status |
      | running | restarted | the application | be accessible |
      | running | snapshot  | the snapshot    | be found |
      | running | tidied    | it              | succeed |
      | running | shown     | it              | succeed |
      | running | stopped   | the application | not be accessible |
      | stopped | started   | the application | be accessible |
      | running | deleted   | the application | not exist |

