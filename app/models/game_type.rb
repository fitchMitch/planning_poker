class GameType < ApplicationRecord
  has_many :games

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
end
