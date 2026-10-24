require "rails_helper"

RSpec.describe User, type: :model do
  describe "#current_game" do
    it "is nil with no participation" do
      user = create(:user)
      expect(user.current_game).to be_nil
    end

    it "returns the game the user participates in" do
      participant = create(:participant)
      expect(participant.user.current_game).to eq(participant.game)
    end

    it "ignores a game the user has left" do
      participant = create(:participant, left_at: Time.current)
      expect(participant.user.current_game).to be_nil
    end
  end
end
