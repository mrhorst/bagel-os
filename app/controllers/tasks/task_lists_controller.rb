module Tasks
  class TaskListsController < ApplicationController
    # GET /tasks/lists/:id — the “focused work” view. Just this list's
    # today + monthly occurrences, scoped tight, no chrome to distract.
    def show
      @task_list = TaskList.find(params[:id])

      @operating_day = OperatingDay.new
      unless @task_list.visible_at?(@operating_day.now)
        redirect_to tasks_root_path, alert: "#{@task_list.name} is not visible on the Tasks screen right now."
        return
      end

      OccurrenceBuilder.new(operating_day: @operating_day).build!(from: @operating_day.today, to: @operating_day.today)
      OccurrenceBuilder.new(operating_day: @operating_day).build!(from: @operating_day.today.beginning_of_month, to: @operating_day.today.end_of_month)

      @today_occurrences   = day_occurrences_for(@task_list, @operating_day)
      @monthly_occurrences = month_occurrences_for(@task_list, @operating_day)
      @metrics = TaskMetrics.new(daily: @today_occurrences, monthly: @monthly_occurrences, operating_day: @operating_day).summary.to_h_with_today_suffix
    end

    # ── Management ──────────────────────────────────────────────────────
    def index
      @task_lists = TaskList.ordered
      @task_counts = Task.active.group(:task_list_id).count
    end

    def new
      @task_list = TaskList.new(position: TaskList.maximum(:position).to_i + 1)
      @continue_to_task = params[:continue_to_task] == "1"
    end

    def create
      @task_list = TaskList.new(task_list_params)
      @task_list.position = TaskList.maximum(:position).to_i + 1 if @task_list.position.to_i.zero?

      if @task_list.save
        LiveUpdates.task_state_changed!
        redirect_to after_create_path(@task_list), notice: "Task list created."
      else
        @continue_to_task = params[:continue_to_task] == "1"
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @task_list = TaskList.find(params[:id])
      @back_path, @back_label = resolve_edit_back_target(@task_list)
    end

    def update
      @task_list = TaskList.find(params[:id])

      if @task_list.update(task_list_params)
        LiveUpdates.task_state_changed!
        redirect_to after_update_path(@task_list), notice: "Task list updated."
      else
        @back_path, @back_label = resolve_edit_back_target(@task_list)
        render :edit, status: :unprocessable_entity
      end
    end

    def archive
      TaskList.find(params[:id]).archive!
      LiveUpdates.task_state_changed!
      redirect_to tasks_manage_lists_path, notice: "Task list archived."
    end

    def reactivate
      TaskList.find(params[:id]).reactivate!
      LiveUpdates.task_state_changed!
      redirect_to tasks_manage_lists_path, notice: "Task list reactivated."
    end

    private

    # The edit page has two entry points across the two Tasks trees, and the
    # back arrow must name (and reach) the one the user actually came from:
    #
    #   • Settings → Task lists → Edit list  → back to the management index
    #   • Work surface → focused list → Edit → back to that focused list
    #
    # The work-surface "Edit list" link carries origin=list so the cross-tree
    # jump resolves its back target to its origin instead of stranding the user
    # in Settings. This mirrors Tasks::OccurrencesController#resolve_back_target:
    # back_path and back_label are decided together server-side so the arrow
    # always lands where its label promises (see app/views/tasks/_subpage_header).
    def resolve_edit_back_target(task_list)
      if params[:origin] == "list"
        [ tasks_list_path(task_list), task_list.name ]
      else
        [ tasks_manage_lists_path, "Task lists" ]
      end
    end

    def task_list_params
      params.require(:task_list).permit(:name, :position, :notes, :display_start_time, :display_end_time)
    end

    # When the user edited from the focused work-surface view, saving returns
    # them there — the same origin the back arrow resolves to — rather than
    # dumping them into the Settings management index.
    def after_update_path(task_list)
      if params[:origin] == "list"
        tasks_list_path(task_list)
      else
        tasks_manage_lists_path
      end
    end

    def after_create_path(task_list)
      if params[:continue_to_task] == "1"
        new_tasks_manage_task_path(task_list_id: task_list.id, flow: "guided", return_to: "dashboard")
      else
        tasks_manage_lists_path
      end
    end

    # Single-list versions of the dashboard queries. Visibility is checked
    # once at the top of #show so a direct URL follows the same work-surface
    # rule as the dashboard.
    def day_occurrences_for(task_list, operating_day)
      operating_day.actionable_daily_scope
        .where(task_list_id: task_list.id)
        .includes(:task_list, :active_completion)
        .reject { |occurrence| occurrence.missed?(operating_day: operating_day) }
        .reject { |occurrence| occurrence.stale_completed_carryover?(operating_day: operating_day) }
        .sort_by { |occurrence| sort_key(occurrence, operating_day) }
    end

    def month_occurrences_for(task_list, operating_day)
      operating_day.actionable_monthly_scope
        .where(task_list_id: task_list.id)
        .includes(:task_list, :active_completion)
        .reject(&:completed?)
        .reject { |occurrence| occurrence.missed?(operating_day: operating_day) }
        .sort_by { |occurrence| [ occurrence.position, occurrence.snapshot_title ] }
    end

    def sort_key(occurrence, operating_day)
      rank = { "late" => 0, "open" => 1, "completed" => 2 }.fetch(occurrence.status(operating_day: operating_day), 3)
      [ rank, occurrence.due_at || Time.zone.local(9999, 1, 1), occurrence.position, occurrence.snapshot_title ]
    end
  end
end
