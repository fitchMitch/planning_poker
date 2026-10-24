FactoryBot.define do
  factory :game_type do
    sequence(:name) { |n| "Planning Poker #{n}" }
    sequence(:slug) { |n| "planning-poker-#{n}" }
    description { "Estimez vos tickets en équipe, en temps réel, par un vote collectif à l'aveugle." }
  end
end
