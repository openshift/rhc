@env_var @domain_required
Feature: Environment Variables Operations

  @init
  Scenario: Application Creation
    When a php application is created
    Then the application should be accessible

  Scenario: Environment variable is set
    When a new environment variable "FOO" is set as "BAR"
    And the existing environment variables are listed
    Then the output environment variables include "FOO=BAR"

  Scenario: Environment variables are set
    When a new environment variable "FOO" is set as "BAR"
    And a new environment variable "FOO2" is set as "BAR2"
    And the existing environment variables are listed
    Then the output environment variables include "FOO=BAR"
    And the output environment variables include "FOO2=BAR2"

  Scenario: Environment variable is unset
    When a new environment variable "FOO" is set as "BAR"
    And the existing environment variables are listed
    Then the output environment variables include "FOO=BAR"
    When an existing environment variable with name "FOO" is unset
    Then the output environment variables do not include "FOO=BAR"

  # Scenario: Create app with environment variable
  # Scenario: add cartridge with environment variable
