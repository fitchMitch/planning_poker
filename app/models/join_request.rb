class JoinRequest < ApplicationRecord
  belongs_to :game
  belongs_to :user

  validates :status, inclusion: { in: %w[pending accepted rejected] }

  def self.current_cycle_for(game:, user:)
    last_left_at = Participant.where(game: game, user: user).maximum(:left_at)
    scope = where(game: game, user: user)
    last_left_at ? scope.where("created_at > ?", last_left_at) : scope
  end

  def self.barred?(game:, user:)
    current_cycle_for(game: game, user: user).where(status: "rejected").count >= 2
  end

  def self.pending_for?(game:, user:)
    current_cycle_for(game: game, user: user).where(status: "pending").exists?
  end

  def retry?
    self.class.current_cycle_for(game: game, user: user).where("id < ?", id).exists?
  end
end
