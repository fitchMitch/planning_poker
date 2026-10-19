Given("I am on the home page") do
  visit root_path
end

When("I sign up with email {string} and password {string}") do |email, password|
  click_link "S'inscrire"
  fill_in "user_email", with: email
  fill_in "user_password", with: password
  fill_in "user_password_confirmation", with: password
  click_button "S'inscrire"
end

Then("I should see {string}") do |text|
  assert page.has_text?(text)
end
