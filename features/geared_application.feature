@geared_application @geared_user_required @domain_required
Feature: Scaled Application Operations

  @init @not-origin
  Scenario: Geared Application Creation
    When a php application is created with a medium gear
    Then the application should be accessible
    Then the application should have a medium gear