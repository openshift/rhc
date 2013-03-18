@geared_application @geared_user_required @domain_required
Feature: Scaled Application Operations

  @init
  Scenario Outline: Geared Application Creation
    When a <php_version> application is created with a medium gear
    Then the application should be accessible
    Then the application should have a medium gear

    @fedora-only
    Scenario: Fedora 18
      | php_version |
      | php-5.4     |

    @rhel-only
    Scenario: RHEL
      | php_version |
      | php-5.3     |



