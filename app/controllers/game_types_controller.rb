class GameTypesController < ApplicationController
  def index
    @game_types = GameType.all
  end

  def show
    @game_type = GameType.find_by!(slug: params[:slug])
  end
end
