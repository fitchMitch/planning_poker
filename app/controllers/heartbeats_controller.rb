class HeartbeatsController < ApplicationController
  before_action :authenticate_user!

  def create
    game = Game.find(params[:id])
    participant = game.participants.active.find_by(user: current_user)
    participant&.touch
    head :no_content
  end
end
