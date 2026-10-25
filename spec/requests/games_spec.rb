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

  describe "POST /games/:id/leave" do
    it "lets a participant leave their game" do
      participant = create(:participant)
      sign_in participant.user

      post leave_game_path(participant.game)

      expect(participant.reload.left_at).not_to be_nil
    end

    it "does nothing if the user is not a participant of that game" do
      game = create(:game)
      other_participant = create(:participant, game: game)
      sign_in create(:user)

      post leave_game_path(game)

      expect(response).to redirect_to(games_path)
      expect(other_participant.reload.left_at).to be_nil
    end
  end

  describe "GET /games/:id" do
    it "shows the game to one of its active participants" do
      participant = create(:participant)
      sign_in participant.user

      get game_path(participant.game)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(participant.game.name)
    end

    it "redirects a non-participant away" do
      game = create(:game)
      sign_in create(:user)

      get game_path(game)

      expect(response).to redirect_to(games_path)
    end

    it "shows pending join requests to an active participant" do
      participant = create(:participant)
      join_request = create(:join_request, game: participant.game)
      sign_in participant.user

      get game_path(participant.game)

      expect(response.body).to include(join_request.user.email)
    end
  end

  describe "GET /games" do
    it "lists open games" do
      open_game = create(:game, state: "lobby")
      create(:game, state: "ended")
      sign_in create(:user)

      get games_path

      expect(response.body).to include(open_game.name)
    end

    it "lists the signed-in user's participation history, including left and ended games" do
      user = create(:user)
      past_participant = create(:participant, user: user, left_at: 1.day.ago)
      sign_in user

      get games_path

      expect(response.body).to include(past_participant.game.name)
    end

    it "renders without error when there are no games at all" do
      sign_in create(:user)
      get games_path
      expect(response).to have_http_status(:success)
    end

    it "shows the creator's email under each open game" do
      creator = create(:user, email: "creator@example.com")
      open_game = create(:game, state: "lobby")
      create(:participant, game: open_game, user: creator, creator: true)
      sign_in create(:user)

      get games_path

      expect(response.body).to include("creator@example.com")
    end

    it "offers to rejoin a game the user left and then rejoined, instead of showing it as ended or left" do
      user = create(:user)
      game = create(:game, state: "in_progress")
      create(:participant, game: game, user: user, left_at: 1.hour.ago)
      create(:participant, game: game, user: user)
      sign_in user

      get games_path

      expect(response.body).to include("Retourner à la partie")
      expect(response.body).not_to include("Terminée")
      expect(response.body).not_to include("Quittée")
    end
  end
end
