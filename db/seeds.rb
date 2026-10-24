# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

GameType.find_or_create_by!(slug: "planning-poker") do |game_type|
  game_type.name = "Planning Poker"
  game_type.description = "Estimez vos tickets en équipe, en temps réel, par un vote collectif à l'aveugle."
end
