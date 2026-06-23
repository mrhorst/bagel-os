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
      # Tuck completed tasks into their own collapsed section so the main list
      # stays focused on what's left to do. Both halves keep the same sort.
      @open_occurrences, @completed_occurrences =
        @today_occurrences.partition { |occurrence| !occurrence.completed? }
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
    end

    def update
      @task_list = TaskList.find(params[:id])

      if @task_list.update(task_list_params)
        LiveUpdates.task_state_changed!
        redirect_to tasks_manage_lists_path, notice: "Task list updated."
      else
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

    def task_list_params
      params.require(:task_list).permit(:name, :position, :notes, :display_start_time, :display_end_time)
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
