require "rails_helper"

RSpec.describe Game, type: :model do
  it "requires a name" do
    game = build(:game, name: nil)
    expect(game).not_to be_valid
    expect(game.errors[:name]).to include("can't be blank")
  end

  it "requires a unique name across the whole platform" do
    create(:game, name: "Sprint 12")
    dup = build(:game, name: "Sprint 12")
    expect(dup).not_to be_valid
    expect(dup.errors[:name]).to include("has already been taken")
  end

  it "defaults state to lobby" do
    game = create(:game)
    expect(game.state).to eq("lobby")
  end

  it "normalizes a blank description to nil" do
    game = create(:game, description: "   ")
    expect(game.description).to be_nil
  end

  it "keeps a present description" do
    game = create(:game, description: "Weekly estimation")
    expect(game.description).to eq("Weekly estimation")
  end
end
