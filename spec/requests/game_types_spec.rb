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
end
