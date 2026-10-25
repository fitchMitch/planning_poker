When("I visit the games list") do
  visit game_type_games_path("planning-poker")
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

Given("{string} has been rejected twice requesting to join {string}") do |email, name|
  user = User.find_by!(email: email)
  game = Game.find_by!(name: name)
  JoinRequest.create!(game: game, user: user, status: "rejected")
  JoinRequest.create!(game: game, user: user, status: "rejected")
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

When("I attempt to request to join {string}") do |name|
  game = Game.find_by!(name: name)
  page.driver.submit :post, game_join_requests_path(game), {}
end

Then("the request to join {string} is refused") do |_name|
  assert_equal 403, page.status_code
end

Given("{string} has been inactive for over 30 minutes in {string}") do |email, name|
  user = User.find_by!(email: email)
  game = Game.find_by!(name: name)
  participant = Participant.find_by!(game: game, user: user)
  participant.update_column(:updated_at, 31.minutes.ago)
end

When("the inactivity timeout job runs") do
  ExpireInactiveParticipantsJob.perform_now
end

Then("I should see {string} marked as ended in \"Mes parties\"") do |name|
  visit game_type_games_path("planning-poker")
  within("section", text: "Mes parties") do
    assert page.has_text?(name)
    assert page.has_text?("Terminée")
  end
end
