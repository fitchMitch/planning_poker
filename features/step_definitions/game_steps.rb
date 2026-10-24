Given("the Planning Poker game type exists") do
  GameType.find_or_create_by!(slug: "planning-poker") do |gt|
    gt.name = "Planning Poker"
    gt.description = "Estimez vos tickets en équipe, en temps réel, par un vote collectif à l'aveugle."
  end
end

Given("I am logged in as {string}") do |email|
  visit new_user_session_path
  fill_in "user_email", with: email
  fill_in "user_password", with: "Password123"
  click_button "Se connecter"
end

When("I visit the home page") do
  visit root_path
end

When("I click on {string}") do |text|
  within(".ds-card", text: text) { click_link "Voir" }
end

When("I visit the Planning Poker game type page") do
  visit game_type_path("planning-poker")
end

Given("a game named {string} exists for the Planning Poker game type") do |name|
  game_type = GameType.find_by!(slug: "planning-poker")
  Game.create!(game_type: game_type, name: name)
end

Given("I am already participating in a game named {string}") do |name|
  game_type = GameType.find_by!(slug: "planning-poker")
  game = Game.create!(game_type: game_type, name: name)
  user = User.find_by!(email: "alice@example.com")
  Participant.create!(game: game, user: user, creator: true)
end

When("I create a game named {string}") do |name|
  visit new_game_type_game_path("planning-poker")
  fill_in "Nom de la partie", with: name
  click_button "Créer"
end

When("I create a game named {string} with description {string}") do |name, description|
  visit new_game_type_game_path("planning-poker")
  fill_in "Nom de la partie", with: name
  fill_in "Description (optionnel)", with: description
  click_button "Créer"
end

Then("the {string} button should be disabled") do |label|
  assert page.has_css?("span.ds-btn[disabled]", text: label)
end
