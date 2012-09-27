@scaled_application @domain_required
Feature: Scaled Application Operations

  @init
  Scenario: Scaled Application Creation
    When a scaled php-5.3 application is created
    Then the application should be accessible
    Then the application should be scalable

  # The state in these examples should be able to be broken into before hooks when we update cucumber
  Scenario Outline: Running Scaled Application Commands
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
      | running | destroyed | the application | not exist |

