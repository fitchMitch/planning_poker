class ExpireInactiveParticipantsJob < ApplicationJob
  def perform
    Participant.active.where(updated_at: ...30.minutes.ago).find_each(&:leave!)
  end
end
