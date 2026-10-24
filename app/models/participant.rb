class Participant < ApplicationRecord
  belongs_to :game
  belongs_to :user

  scope :active, -> { where(left_at: nil) }

  validate :user_has_no_other_active_game, on: :create

  def leave!(successor: nil)
    transaction do
      update!(left_at: Time.current)
      remaining = game.participants.active.where.not(id: id)

      if remaining.none?
        game.update!(state: "ended")
      elsif creator? && game.state == "lobby"
        game.update!(state: "ended")
        remaining.each(&:leave!)
      elsif creator? && game.state == "in_progress"
        next_creator = successor || remaining.sample
        next_creator.update!(creator: true)
      end
    end
  end

  private

  def user_has_no_other_active_game
    return if user.nil?
    return unless user.participants.active.where.not(game_id: game_id).exists?

    errors.add(:user, "is already participating in another game")
  end
end
