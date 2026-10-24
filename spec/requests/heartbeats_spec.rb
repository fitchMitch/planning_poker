require "rails_helper"

RSpec.describe "Heartbeats", type: :request do
  it "touches the current user's participant row for that game" do
    participant = create(:participant, updated_at: 1.hour.ago)
    sign_in participant.user

    post heartbeat_game_path(participant.game)

    expect(participant.reload.updated_at).to be_within(5.seconds).of(Time.current)
  end

  it "does not touch another user's participant row" do
    other_participant = create(:participant, updated_at: 1.hour.ago)
    sign_in create(:user)

    post heartbeat_game_path(other_participant.game)

    expect(other_participant.reload.updated_at).to be_within(1.second).of(1.hour.ago)
  end

  it "only touches the caller's own participant row when another participant shares the same game" do
    game = create(:game)
    caller_participant = create(:participant, game: game, updated_at: 1.hour.ago)
    other_participant = create(:participant, game: game, updated_at: 1.hour.ago)
    sign_in caller_participant.user

    post heartbeat_game_path(game)

    expect(caller_participant.reload.updated_at).to be_within(5.seconds).of(Time.current)
    expect(other_participant.reload.updated_at).to be_within(1.second).of(1.hour.ago)
  end
end
