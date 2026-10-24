Feature: Game creation

  Background:
    Given the Planning Poker game type exists
    And a user exists with email "alice@example.com"
    And I am logged in as "alice@example.com"

  Scenario: A member creates a game with a name only
    When I create a game named "Sprint 42"
    Then I should see "Sprint 42"

  Scenario: A member creates a game with a name and a description
    When I create a game named "Sprint 43" with description "Weekly estimation"
    Then I should see "Sprint 43"

  Scenario: A member cannot create a game with a name already taken
    Given a game named "Sprint 44" exists for the Planning Poker game type
    When I create a game named "Sprint 44"
    Then I should see "has already been taken"

  Scenario: A member already in a game cannot create another one
    Given I am already participating in a game named "Sprint 45"
    When I visit the Planning Poker game type page
    Then the "Créer une partie" button should be disabled
    And I should see "Vous participez déjà à Sprint 45"

  Scenario: A member already in a game sees an error when forcing the creation form
    Given I am already participating in a game named "Sprint 46"
    When I try to create a game named "Sprint 47"
    Then I should see "Vous participez déjà à Sprint 46"
