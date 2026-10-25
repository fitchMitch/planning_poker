class Game < ApplicationRecord
  belongs_to :game_type
  has_many :participants
  has_many :join_requests

  scope :open, -> { where(state: %w[lobby in_progress]) }

  normalizes :description, with: ->(value) { value.blank? ? nil : value }

  validates :name, presence: true, uniqueness: true

  def open?
    state.in?(%w[lobby in_progress])
  end

  def creator
    participants.find_by(creator: true)&.user
  end
end
