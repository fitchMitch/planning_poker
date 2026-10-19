When("I visit {string}") do |path|
  visit path
end

Then("the response status should be {int}") do |status|
  assert_equal status, page.status_code
end
