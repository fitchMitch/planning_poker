require "rails_helper"

RSpec.describe ExpireInactiveParticipantsJob, type: :job do
  it "leaves participants inactive for more than 30 minutes" do
    stale_participant = create(:participant)
    stale_participant.update_column(:updated_at, 31.minutes.ago)
    fresh_participant = create(:participant)

    described_class.perform_now

    expect(stale_participant.reload.left_at).not_to be_nil
    expect(fresh_participant.reload.left_at).to be_nil
  end
end
