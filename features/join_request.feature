Feature: Requesting to join a game

  Background:
    Given the Planning Poker game type exists
    And a user exists with email "alice@example.com"
    And a user exists with email "bob@example.com"
    And "alice@example.com" created a game named "Sprint 60"

  Scenario: A member requests to join an open game
    Given I am logged in as "bob@example.com"
    When I visit the games list
    And I request to join "Sprint 60"
    Then I should see "En attente"

  Scenario: The creator accepts a join request
    Given "bob@example.com" has requested to join "Sprint 60"
    And I am logged in as "alice@example.com"
    When I visit the game page for "Sprint 60"
    And I accept the join request from "bob@example.com"
    Then "bob@example.com" becomes a participant of "Sprint 60"
