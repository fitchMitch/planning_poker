When("I log in with email {string} and password {string}") do |email, password|
  click_link "Se connecter"
  fill_in "user_email", with: email
  fill_in "user_password", with: password
  click_button "Se connecter"
end
