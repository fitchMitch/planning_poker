require "rails_helper"

RSpec.describe "JoinRequests", type: :request do
  let(:game) { create(:game) }
  let(:user) { create(:user) }

  before { sign_in user }

  it "creates a pending join request" do
    post game_join_requests_path(game)
    expect(JoinRequest.last).to have_attributes(game: game, user: user, status: "pending")
  end

  it "rejects a user barred by two prior rejections" do
    create(:join_request, game: game, user: user, status: "rejected")
    create(:join_request, game: game, user: user, status: "rejected")

    expect {
      post game_join_requests_path(game)
    }.not_to change(JoinRequest, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a user already an active participant of another game" do
    create(:participant, user: user)

    expect {
      post game_join_requests_path(game)
    }.not_to change(JoinRequest, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a second request while one is already pending for the same game" do
    create(:join_request, game: game, user: user, status: "pending")

    expect {
      post game_join_requests_path(game)
    }.not_to change(JoinRequest, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a request for a game that has ended" do
    ended_game = create(:game, state: "ended")

    expect {
      post game_join_requests_path(ended_game)
    }.not_to change(JoinRequest, :count)
    expect(response).to have_http_status(:forbidden)
  end

  describe "PATCH /join_requests/:id/accept" do
    it "lets any current active participant accept a first attempt" do
      game = create(:game)
      deciding_participant = create(:participant, game: game)
      join_request = create(:join_request, game: game)
      sign_in deciding_participant.user

      patch accept_join_request_path(join_request)

      expect(join_request.reload.status).to eq("accepted")
      expect(Participant.active.exists?(game: game, user: join_request.user)).to eq(true)
    end

    it "rejects acceptance from a non-participant" do
      join_request = create(:join_request)
      sign_in create(:user)

      patch accept_join_request_path(join_request)

      expect(join_request.reload.status).to eq("pending")
      expect(response).to have_http_status(:forbidden)
    end

    it "only lets the creator accept a retry" do
      game = create(:game)
      creator = create(:participant, game: game, creator: true)
      other_participant = create(:participant, game: game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      retry_request = create(:join_request, game: game, user: user)
      sign_in other_participant.user

      patch accept_join_request_path(retry_request)

      expect(retry_request.reload.status).to eq("pending")
      expect(response).to have_http_status(:forbidden)
    end

    it "does not change an already-decided request" do
      join_request = create(:join_request, status: "accepted")
      deciding_participant = create(:participant, game: join_request.game)
      sign_in deciding_participant.user

      patch reject_join_request_path(join_request)

      expect(join_request.reload.status).to eq("accepted")
    end

    it "rejects the request instead of accepting it when the user has since joined another game" do
      game = create(:game)
      deciding_participant = create(:participant, game: game)
      join_request = create(:join_request, game: game)
      create(:participant, user: join_request.user) # joined a different game meanwhile
      sign_in deciding_participant.user

      patch accept_join_request_path(join_request)

      expect(join_request.reload.status).to eq("rejected")
      expect(Participant.active.exists?(game: game, user: join_request.user)).to eq(false)
    end
  end

  describe "PATCH /join_requests/:id/reject" do
    it "lets any current active participant reject a first attempt" do
      game = create(:game)
      deciding_participant = create(:participant, game: game)
      join_request = create(:join_request, game: game)
      sign_in deciding_participant.user

      patch reject_join_request_path(join_request)

      expect(join_request.reload.status).to eq("rejected")
    end

    it "permanently bars the user after a second rejection" do
      game = create(:game)
      creator = create(:participant, game: game, creator: true)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      retry_request = create(:join_request, game: game, user: user)
      sign_in creator.user

      patch reject_join_request_path(retry_request)

      expect(JoinRequest.barred?(game: game, user: user)).to eq(true)
    end
  end
end
