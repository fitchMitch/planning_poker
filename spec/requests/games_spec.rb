require "rails_helper"

RSpec.describe "Games", type: :request do
  let!(:game_type) { create(:game_type) }
  let(:user) { create(:user) }

  before { sign_in user }

  it "creates a game and makes the user its creator participant" do
    post game_type_games_path(game_type.slug), params: { game: { name: "Sprint 1", description: "Weekly" } }

    game = Game.find_by(name: "Sprint 1")
    expect(game).not_to be_nil
    expect(response).to redirect_to(game_type_path(game_type.slug))
    participant = game.participants.find_by(user: user)
    expect(participant.creator).to eq(true)
  end

  it "normalizes a blank description to nil" do
    post game_type_games_path(game_type.slug), params: { game: { name: "Sprint 2", description: "   " } }
    expect(Game.find_by(name: "Sprint 2").description).to be_nil
  end

  it "rejects a duplicate game name" do
    create(:game, game_type: game_type, name: "Sprint 3")
    expect {
      post game_type_games_path(game_type.slug), params: { game: { name: "Sprint 3" } }
    }.not_to change(Game, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects creation when the user already has an active game" do
    existing = create(:game, game_type: game_type, name: "Sprint 4")
    create(:participant, game: existing, user: user, creator: true)

    expect {
      post game_type_games_path(game_type.slug), params: { game: { name: "Sprint 5" } }
    }.not_to change(Game, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Vous participez déjà à Sprint 4")
  end
end
