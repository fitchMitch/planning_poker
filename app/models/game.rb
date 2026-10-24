class Game < ApplicationRecord
  belongs_to :game_type
  has_many :participants
  has_many :join_requests

  normalizes :description, with: ->(value) { value.blank? ? nil : value }

  validates :name, presence: true, uniqueness: true
end
