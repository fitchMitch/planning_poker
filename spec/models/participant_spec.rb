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
end
