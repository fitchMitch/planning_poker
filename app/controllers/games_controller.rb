class GamesController < ApplicationController
  before_action :authenticate_user!

  def index
    @open_games = Game.open
    @my_games = Game.joins(:participants).where(participants: { user: current_user }).distinct
  end

  def new
    @game_type = GameType.find_by!(slug: params[:game_type_slug])
    @game = Game.new
  end

  def create
    @game_type = GameType.find_by!(slug: params[:game_type_slug])
    @game = Game.new(game_params.merge(game_type: @game_type))

    if current_user.current_game
      @game.errors.add(:base, "Vous participez déjà à #{current_user.current_game.name}")
      return render :new, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      @game.save!
      Participant.create!(game: @game, user: current_user, creator: true)
    end
    redirect_to game_type_path(@game_type.slug)
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def show
    @game = Game.find(params[:id])
    @current_participant = @game.participants.active.find_by(user: current_user)
    return redirect_to(games_path) unless @current_participant

    @participants = @game.participants.active
    @pending_join_requests = @game.join_requests.where(status: "pending")
  end

  def leave
    game = Game.find(params[:id])
    participant = game.participants.active.find_by(user: current_user)
    participant&.leave!
    redirect_to games_path
  end

  private

  def game_params
    params.require(:game).permit(:name, :description)
  end
end
