FactoryBot.define do
  factory :game_type do
    name { "Planning Poker" }
    slug { "planning-poker" }
    description { "Estimez vos tickets en équipe, en temps réel, par un vote collectif à l'aveugle." }
  end
end
