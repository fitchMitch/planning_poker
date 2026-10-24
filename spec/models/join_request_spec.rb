require "rails_helper"

RSpec.describe JoinRequest, type: :model do
  it "requires a game" do
    expect(build(:join_request, game: nil)).not_to be_valid
  end

  it "requires a user" do
    expect(build(:join_request, user: nil)).not_to be_valid
  end

  it "defaults to pending" do
    expect(create(:join_request).status).to eq("pending")
  end

  describe ".barred?" do
    it "is false with no prior join requests" do
      game = create(:game)
      user = create(:user)
      expect(JoinRequest.barred?(game: game, user: user)).to eq(false)
    end

    it "is false after a single rejected attempt (the user may retry)" do
      game = create(:game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      expect(JoinRequest.barred?(game: game, user: user)).to eq(false)
    end

    it "is true after a second rejected attempt" do
      game = create(:game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      create(:join_request, game: game, user: user, status: "rejected")
      expect(JoinRequest.barred?(game: game, user: user)).to eq(true)
    end

    it "resets once the user has left and returned — a prior cycle's 2 rejections don't carry over" do
      game = create(:game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      create(:join_request, game: game, user: user, status: "rejected")
      # the user was eventually accepted (in reality, after a 3rd request this
      # spec doesn't model directly) and then left — left_at must be after the
      # rejected requests above, as it would be in real usage (Time.current):
      create(:participant, game: game, user: user, left_at: Time.current)

      expect(JoinRequest.barred?(game: game, user: user)).to eq(false)
    end
  end

  describe "#retry?" do
    it "is false for a user's first request on a game" do
      join_request = create(:join_request)
      expect(join_request.retry?).to eq(false)
    end

    it "is true for a user's second request on the same game" do
      game = create(:game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      second = create(:join_request, game: game, user: user)
      expect(second.retry?).to eq(true)
    end

    it "is false for a request made in a new cycle after the user left and returned" do
      game = create(:game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      # left_at must be after the rejected request above, as it would be in
      # real usage (Time.current):
      create(:participant, game: game, user: user, left_at: Time.current)
      new_cycle_request = create(:join_request, game: game, user: user)

      expect(new_cycle_request.retry?).to eq(false)
    end
  end
end
