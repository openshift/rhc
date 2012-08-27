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

    # Breaking these examples up so they can flow logically, but also be run individually
    @running
    Examples:
      | command   | what            | status |
      | restarted | the application | be accessible |
      | snapshot  | the snapshot    | be found |
      | tidied    | it              | succeed |
      | shown     | it              | succeed |

    @running
    Examples:
      | command   | what            | status |
      | stopped   | the application | not be accessible |

    @stopped
    Examples:
      | command   | what            | status |
      | started   | the application | be accessible |

    @running
    Examples:
      | command   | what            | status |
      | destroyed | the application | not exist |
