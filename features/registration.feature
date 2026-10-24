Feature: User registration

  Scenario: A visitor signs up
    Given I am on the home page
    When I sign up with email "alice@example.com" and password "Password123"
    Then I should see "alice@example.com"

  Scenario: A visitor signs up with an email already taken
    Given a user exists with email "alice@example.com"
    And I am on the home page
    When I sign up with email "alice@example.com" and password "Password123"
    Then I should see "Email has already been taken"

  Scenario: A visitor signs up with a password missing complexity
    Given I am on the home page
    When I sign up with email "bob@example.com" and password "password"
    Then I should see "doit contenir au moins un chiffre, une minuscule et une majuscule"

  Scenario: A visitor signs up with mismatched password confirmation
    Given I am on the home page
    When I sign up with email "carol@example.com" and password "Password123" confirmed by "Other12345"
    Then I should see "Password confirmation doesn't match Password"

  Scenario: A visitor signs up with a blank email
    Given I am on the home page
    When I sign up with email "" and password "Password123"
    Then I should see "Email can't be blank"
