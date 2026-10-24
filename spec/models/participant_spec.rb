require "rails_helper"

RSpec.describe Participant, type: :model do
  it "requires a game" do
    participant = build(:participant, game: nil)
    expect(participant).not_to be_valid
  end

  it "requires a user" do
    participant = build(:participant, user: nil)
    expect(participant).not_to be_valid
  end

  it "rejects a second active participation for the same user" do
    user = create(:user)
    create(:participant, user: user)
    second = build(:participant, user: user)
    expect(second).not_to be_valid
    expect(second.errors[:user]).to include("is already participating in another game")
  end

  it "defaults creator to false" do
    participant = create(:participant)
    expect(participant.creator).to eq(false)
  end

  describe ".active" do
    it "excludes participants who have left" do
      game_type = create(:game_type)
      left_participant = create(:participant, game: create(:game, game_type: game_type), left_at: Time.current)
      active_participant = create(:participant, game: create(:game, game_type: game_type))
      expect(Participant.active).to contain_exactly(active_participant)
    end
  end

  it "allows a user to join a new game once they've left their previous one" do
    user = create(:user)
    old_game = create(:game)
    create(:participant, game: old_game, user: user, left_at: 1.hour.ago)
    new_participant = build(:participant, user: user)
    expect(new_participant).to be_valid
  end

  describe "#leave!" do
    it "sets left_at" do
      participant = create(:participant)
      participant.leave!
      expect(participant.reload.left_at).not_to be_nil
    end

    it "ends the game when the last active participant leaves" do
      participant = create(:participant)
      participant.leave!
      expect(participant.game.reload.state).to eq("ended")
    end

    it "ends a lobby game immediately when its creator leaves, taking remaining participants with it" do
      game = create(:game, state: "lobby")
      creator = create(:participant, game: game, creator: true)
      other = create(:participant, game: game)

      creator.leave!

      expect(game.reload.state).to eq("ended")
      expect(other.reload.left_at).not_to be_nil
    end

    it "promotes a random remaining active participant to creator when the creator leaves an in_progress game with no successor given" do
      game = create(:game, state: "in_progress")
      creator = create(:participant, game: game, creator: true)
      other = create(:participant, game: game)

      creator.leave!

      expect(other.reload.creator).to eq(true)
      expect(game.reload.state).to eq("in_progress")
    end

    it "promotes an explicitly given successor when the creator leaves an in_progress game" do
      game = create(:game, state: "in_progress")
      creator = create(:participant, game: game, creator: true)
      chosen_successor = create(:participant, game: game)
      create(:participant, game: game) # a third participant, not chosen

      creator.leave!(successor: chosen_successor)

      expect(chosen_successor.reload.creator).to eq(true)
    end
  end
end
