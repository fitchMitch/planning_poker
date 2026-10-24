require "rails_helper"

RSpec.describe GameType, type: :model do
  it "requires a name" do
    game_type = build(:game_type, name: nil)
    expect(game_type).not_to be_valid
    expect(game_type.errors[:name]).to include("can't be blank")
  end

  it "requires a unique name" do
    existing = create(:game_type)
    dup = build(:game_type, name: existing.name, slug: "other")
    expect(dup).not_to be_valid
    expect(dup.errors[:name]).to include("has already been taken")
  end

  it "requires a unique slug" do
    existing = create(:game_type)
    dup = build(:game_type, name: "Other", slug: existing.slug)
    expect(dup).not_to be_valid
    expect(dup.errors[:slug]).to include("has already been taken")
  end
end
