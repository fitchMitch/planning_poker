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
end
