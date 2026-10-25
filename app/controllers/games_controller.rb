class GamesController < ApplicationController
  PER_PAGE = 20

  before_action :authenticate_user!

  def index
    @game_type = GameType.find_by!(slug: params[:game_type_slug])
    games = @game_type.games.open.order(created_at: :desc)
    @page = current_page
    @total_pages = (games.count / PER_PAGE.to_f).ceil
    @open_games = games.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
  end

  def mine
    @game_type = GameType.find_by!(slug: params[:game_type_slug])
    games = @game_type.games
                      .joins(:participants)
                      .where(participants: { user: current_user })
                      .distinct
                      .order(created_at: :desc)
    @page = current_page
    @total_pages = (games.count / PER_PAGE.to_f).ceil
    @my_games = games.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
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
    return redirect_to(game_type_games_path(@game.game_type.slug)) unless @current_participant

    @participants = @game.participants.active
    @pending_join_requests = @game.join_requests.where(status: "pending")
  end

  def leave
    game = Game.find(params[:id])
    participant = game.participants.active.find_by(user: current_user)
    successor = game.participants.active.where.not(id: participant&.id).find_by(id: params[:successor_id])
    participant&.leave!(successor: successor)
    redirect_to game_type_games_path(game.game_type.slug)
  end

  def update
    @game = Game.find(params[:id])
    return head :forbidden unless @game.participants.active.exists?(user: current_user, creator: true)

    @game.update!(description_params)
    redirect_to game_path(@game)
  end

  private

  def game_params
    params.require(:game).permit(:name, :description)
  end

  def description_params
    params.require(:game).permit(:description)
  end

  def current_page
    [ params[:page].to_i, 1 ].max
  end
end
