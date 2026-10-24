class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { member: 0, admin: 1 }

  has_many :participants

  def current_game
    participants.first&.game
  end

  validate :password_complexity

  private

  def password_complexity
    return if password.blank?

    unless password.match?(/\d/) && password.match?(/[a-z]/) && password.match?(/[A-Z]/)
      errors.add :password, "doit contenir au moins un chiffre, une minuscule et une majuscule"
    end
  end
end
