Feature: GameType listing

  Background:
    Given the Planning Poker game type exists

  Scenario: A visitor sees the list of game types on the home page
    When I visit the home page
    Then I should see "Planning Poker"

  Scenario: A visitor opens the Planning Poker game type
    Given I am on the home page
    When I click on "Planning Poker"
    Then I should see "Estimez vos tickets en équipe"

  Scenario: A signed-in member sees the listing and their dashboard unchanged
    Given a user exists with email "dana@example.com"
    And I am logged in as "dana@example.com"
    When I visit the home page
    Then I should see "Planning Poker"
    When I click on "Planning Poker"
    Then I should see "Bon retour !"
