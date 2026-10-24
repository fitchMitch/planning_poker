Feature: Game listing

  Background:
    Given the Planning Poker game type exists
    And a user exists with email "alice@example.com"
    And I am logged in as "alice@example.com"

  Scenario: A member sees an open game in "Toutes les parties"
    Given a game named "Sprint 50" exists for the Planning Poker game type
    When I visit the games list
    Then I should see "Sprint 50"

  Scenario: A member sees their own past participation in "Mes parties"
    Given I am already participating in a game named "Sprint 51"
    When I visit the games list
    Then I should see "Sprint 51"
