class JoinRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_join_request, only: [ :accept, :reject ]

  def create
    game = Game.find(params[:game_id])
    return head :forbidden if JoinRequest.barred?(game: game, user: current_user)

    JoinRequest.create!(game: game, user: current_user)
    redirect_to games_path
  end

  def accept
    return head :forbidden unless authorized_to_decide?
    return if @join_request.status != "pending"

    Participant.create!(game: @join_request.game, user: @join_request.user, creator: false)
    @join_request.update!(status: "accepted")
    redirect_to game_path(@join_request.game)
  rescue ActiveRecord::RecordInvalid
    @join_request.update!(status: "rejected")
    redirect_to game_path(@join_request.game)
  end

  def reject
    return head :forbidden unless authorized_to_decide?
    return if @join_request.status != "pending"

    @join_request.update!(status: "rejected")
    redirect_to game_path(@join_request.game)
  end

  private

  def set_join_request
    @join_request = JoinRequest.find(params[:id])
  end

  def authorized_to_decide?
    game = @join_request.game
    is_participant = Participant.active.exists?(game: game, user: current_user)
    return false unless is_participant

    return true unless @join_request.retry?

    Participant.active.exists?(game: game, user: current_user, creator: true)
  end
end
