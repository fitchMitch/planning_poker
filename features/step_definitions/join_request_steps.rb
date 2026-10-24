When("I visit the games list") do
  visit games_path
end

Given("{string} created a game named {string}") do |email, name|
  user = User.find_by!(email: email)
  game_type = GameType.find_by!(slug: "planning-poker")
  game = Game.create!(game_type: game_type, name: name)
  Participant.create!(game: game, user: user, creator: true)
end

When("I request to join {string}") do |name|
  game = Game.find_by!(name: name)
  within(".ds-card", text: name) { click_button "Demander à rejoindre" }
end

Given("{string} has requested to join {string}") do |email, name|
  user = User.find_by!(email: email)
  game = Game.find_by!(name: name)
  JoinRequest.create!(game: game, user: user)
end

When("I visit the game page for {string}") do |name|
  game = Game.find_by!(name: name)
  visit game_path(game)
end

When("I accept the join request from {string}") do |email|
  within(".ds-card", text: email) { click_button "Accepter" }
end

Then("{string} becomes a participant of {string}") do |email, name|
  user = User.find_by!(email: email)
  game = Game.find_by!(name: name)
  assert Participant.active.exists?(game: game, user: user)
end

When("I click {string}") do |label|
  click_button label
end

Then("I should see {string} marked as ended in \"Mes parties\"") do |name|
  visit games_path
  within("section", text: "Mes parties") do
    assert page.has_text?(name)
    assert page.has_text?("Terminée")
  end
end
