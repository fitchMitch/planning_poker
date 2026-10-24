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
end
