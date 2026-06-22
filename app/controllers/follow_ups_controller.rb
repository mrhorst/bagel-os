class FollowUpsController < ApplicationController
  require_module_access :follow_ups

  before_action :load_follow_up, only: %i[show resolve reopen assign spawn_task]

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

  def assign
    assignee_id = params[:assigned_to_id].presence
    @follow_up.update!(assigned_to_id: assignee_id)
    redirect_to follow_up_path(@follow_up),
      notice: assignee_id ? "Assigned." : "Unassigned."
  end

  def spawn_task
    spawn_params = params.require(:spawn).permit(:title, :description, :link_kind, :recurrence_type, :task_list_id, :one_time_on, :due_time, :auto_resolve, weekdays: [])
    result = FollowUps::SpawnTask.new(@follow_up, params: spawn_params, user: Current.user).call

    if result.ok?
      redirect_to follow_up_path(@follow_up), notice: "Task created: #{result.task.title}"
    else
      # Re-render the detail page with the form repopulated and the errors shown,
      # rather than redirecting — a redirect would drop everything the user typed.
      @spawn = spawn_params
      @spawn_errors = result.errors
      render :show, status: :unprocessable_entity
    end
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
