Feature: User login

  Scenario: A user logs in with valid credentials
    Given a user exists with email "alice@example.com"
    And I am on the home page
    When I log in with email "alice@example.com" and password "Password123"
    Then I should see "alice@example.com"

  Scenario: A user logs in with the wrong password
    Given a user exists with email "alice@example.com"
    And I am on the home page
    When I log in with email "alice@example.com" and password "WrongPass123"
    Then I should see "Invalid email or password."
