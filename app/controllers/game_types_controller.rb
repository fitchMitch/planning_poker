class GameTypesController < ApplicationController
  def index
    @game_types = GameType.all
  end

  def show
    @game_type = GameType.find_by!(slug: params[:slug])
    @recent_games = @game_type.games.order(created_at: :desc).limit(5)
    if user_signed_in?
      @my_games = @game_type.games
                             .joins(:participants)
                             .where(participants: { user: current_user })
                             .distinct
                             .order(created_at: :desc)
    end
  end
end
