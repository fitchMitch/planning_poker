FactoryBot.define do
  factory :game do
    game_type
    sequence(:name) { |n| "Sprint #{n}" }
  end
end
