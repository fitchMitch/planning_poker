Feature: User registration

  Scenario: A visitor signs up
    Given I am on the home page
    When I sign up with email "alice@example.com" and password "password123"
    Then I should see "Connecté en tant que"
    And I should see "alice@example.com"
