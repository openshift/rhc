@scaled_application @domain_required
Feature: Scaled Application Operations

  @init
  Scenario Outline: Scaled Application Creation
    When a scaled <php_version> application is created
    Then the application should be accessible
    Then the application should be scalable

    @fedora-only
    Scenario: Fedora 18
      | php_version |
      | php-5.4     |

    @rhel-only
    Scenario: RHEL
      | php_version |
      | php-5.3     |

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
      # After the app is deleted, it is resolving to the OpenShift server
      #   I think it's because of US2108
      #   TODO: This needs to be fixed by "not exist" checking DNS instead of HTTP
      | running | deleted   | it              | succeed |

  Scenario Outline: Changing Scaling Value
    When we are updating the <cart> cartridge
    And the <type> scaling value is set to <value>
    Then the <type> scaling value should be <value>

    @fedora-only
    Examples:
      | cart    | type  | value |
      | php-5.4 | min   |   1   |
      | php-5.4 | max   |   5   |
      | php-5.4 | max   |   -1  |

    @rhel-only
    Examples:
      | cart    | type  | value |
      | php-5.3 | min   |   1   |
      | php-5.3 | max   |   5   |
      | php-5.3 | max   |   -1  |

  Scenario Outline: Invalid Scaling Values
    When we are updating the <cart> cartridge
    And the <type> scaling value is set to <value>
    Then it should fail with code <code>

    @fedora-only
    Examples: Fedora 18
      | cart    | type  | value | code |
      | php-5.4 | min   |   a   |  1   |

    @rhel-only
    Examples: RHEL
      | cart    | type  | value | code |
      | php-5.3 | min   |   a   |  1   |
