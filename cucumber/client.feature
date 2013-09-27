@client
Feature: Client Integration Tests
  Background:
    Given the libra client tools

  @init
  Scenario: Setup Wizard
    When the setup wizard is run
    Then the client tools should be setup

  Scenario: Get Server Status
