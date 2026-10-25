require "rails_helper"

RSpec.describe "GameTypes", type: :request do
  let!(:game_type) { create(:game_type, name: "Planning Poker", slug: "planning-poker") }

  describe "GET /" do
    it "lists game types" do
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Planning Poker")
    end
  end

  describe "GET /game_types/:slug" do
    it "renders the game type's page" do
      get game_type_path(game_type.slug)
      expect(response).to have_http_status(:success)
    end

    it "404s for an unknown slug" do
      get game_type_path("does-not-exist")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /game_types/:slug recent games preview" do
    it "shows up to 5 of the game type's most recently created games" do
      game_type = create(:game_type)
      6.times { |n| create(:game, game_type: game_type, name: "Game #{n}") }
      sign_in create(:user)

      get game_type_path(game_type.slug)

      expect(response.body).to include("Game 5") # most recent
      expect(response.body).not_to include("Game 0") # 6th-oldest, excluded
    end
  end

  describe "GET /game_types/:slug Mes parties" do
    it "only lists the user's games for this game type, not other game types" do
      user = create(:user)
      other_user = create(:user)
      matching_game = create(:game, game_type: game_type, name: "My Sprint")
      create(:participant, game: matching_game, user: user, left_at: 1.hour.ago)

      other_game_type = create(:game_type)
      other_type_game = create(:game, game_type: other_game_type, name: "Other Type Sprint")
      create(:participant, game: other_type_game, user: user, left_at: 1.hour.ago)

      other_users_game = create(:game, game_type: game_type, name: "Someone Else's Sprint")
      create(:participant, game: other_users_game, user: other_user)

      sign_in user

      get game_type_path(game_type.slug)

      expect(response.body).to include("My Sprint")
      expect(response.body).not_to include("Other Type Sprint")
      expect(response.body).not_to include("Someone Else's Sprint")
    end
  end
end
