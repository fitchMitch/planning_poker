class JoinRequestsController < ApplicationController
  before_action :authenticate_user!

  def create
    game = Game.find(params[:game_id])
    if JoinRequest.barred?(game: game, user: current_user)
      return head :forbidden
    end

    JoinRequest.create!(game: game, user: current_user)
    redirect_to games_path
  end
end
