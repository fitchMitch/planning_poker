Given("I am on the home page") do
  visit root_path
end

Given("a user exists with email {string}") do |email|
  User.create!(email: email, password: "Password123", password_confirmation: "Password123")
end

When("I sign up with email {string} and password {string}") do |email, password|
  click_link "S'inscrire"
  fill_in "user_email", with: email
  fill_in "user_password", with: password
  fill_in "user_password_confirmation", with: password
  click_button "S'inscrire"
end

When("I sign up with email {string} and password {string} confirmed by {string}") do |email, password, confirmation|
  click_link "S'inscrire"
  fill_in "user_email", with: email
  fill_in "user_password", with: password
  fill_in "user_password_confirmation", with: confirmation
  click_button "S'inscrire"
end

Then("I should see {string}") do |text|
  assert page.has_text?(text)
end
