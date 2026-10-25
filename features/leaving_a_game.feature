Feature: Leaving a game

  Background:
    Given the Planning Poker game type exists
    And a user exists with email "alice@example.com"
    And I am logged in as "alice@example.com"
    And I am already participating in a game named "Sprint 70"

  Scenario: A participant leaves their game
    When I visit the game page for "Sprint 70"
    And I click "Quitter la partie"
    Then I should see "Sprint 70" marked as ended in "Mes parties"

  Scenario: An inactive participant is automatically removed, same as an explicit leave
    When "alice@example.com" has been inactive for over 30 minutes in "Sprint 70"
    And the inactivity timeout job runs
    Then I should see "Sprint 70" marked as ended in "Mes parties"
