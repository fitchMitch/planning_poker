Feature: Health check

  Scenario: The application reports that it is running
    When I visit "/up"
    Then the response status should be 200
