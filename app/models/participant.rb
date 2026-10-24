class Participant < ApplicationRecord
  belongs_to :game
  belongs_to :user

  validate :user_has_no_other_active_game, on: :create

  private

  def user_has_no_other_active_game
    return if user.nil?
    return unless user.participants.where.not(game_id: game_id).exists?

    errors.add(:user, "is already participating in another game")
  end
end
