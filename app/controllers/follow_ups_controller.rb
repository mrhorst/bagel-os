class FollowUpsController < ApplicationController
  require_module_access :follow_ups

  before_action :load_follow_up, only: %i[show resolve reopen]

  def index
    @scope = scope_from_params
    @follow_ups = follow_ups_for(@scope)
    @open_count     = FollowUp.open.count
    @resolved_count = FollowUp.resolved.count
  end

  def show
  end

  def resolve
    @follow_up.resolve!(
      user: Current.user,
      note: params[:resolution_note].presence,
      via:  params[:resolved_via].presence || "action_taken"
    )
    redirect_to follow_ups_path, notice: "Follow-up resolved."
  end

  def reopen
    @follow_up.reopen!(user: Current.user)
    redirect_to follow_up_path(@follow_up), notice: "Follow-up reopened."
  end

  private

  def load_follow_up
    @follow_up = FollowUp.includes(notes: :author).find(params[:id])
  end

  def scope_from_params
    case params[:scope]
    when "resolved" then "resolved"
    else "open"
    end
  end

  def follow_ups_for(scope)
    base = FollowUp.public_send(scope).includes(:origin, :opened_by, :resolved_by)
    scope == "open" ? base.by_urgency : base.recent_first
  end
end
