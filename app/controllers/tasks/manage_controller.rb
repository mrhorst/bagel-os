module Tasks
  # /tasks/manage/tasks — CRUD for the task definitions themselves.
  # We keep the controller name "Manage" because the controller predates
  # the resourceful URL; renaming the file would just be churn.
  class ManageController < ApplicationController
    before_action :load_form_collections, only: %i[index setup new create edit update]

    def index
      @tasks = Task.includes(:task_list).joins(:task_list)
        .order("task_lists.position ASC", "tasks.position ASC", "tasks.title ASC")
    end

    def setup
    end

    def new
      @task = Task.new(
        task_list_id: params[:task_list_id],
        recurrence_type: "daily",
        starts_on: Time.zone.today
      )
    end

    def create
      @task = Task.new(task_params)

      if @task.save
        refresh_open_occurrences(@task)
        LiveUpdates.task_state_changed!
        redirect_to after_create_path, notice: "Task created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @task = Task.find(params[:id])
      @back_path, @back_label = resolve_edit_back_target(@task)
    end

    def update
      @task = Task.find(params[:id])

      if @task.update(task_params)
        refresh_open_occurrences(@task)
        LiveUpdates.task_state_changed!
        redirect_to after_update_path(@task), notice: "Task updated."
      else
        @back_path, @back_label = resolve_edit_back_target(@task)
        render :edit, status: :unprocessable_entity
      end
    end

    def archive
      Task.find(params[:id]).archive!
      LiveUpdates.task_state_changed!
      redirect_to tasks_manage_tasks_path, notice: "Task archived."
    end

    def reactivate
      task = Task.find(params[:id])
      task.reactivate!
      refresh_open_occurrences(task)
      LiveUpdates.task_state_changed!
      redirect_to tasks_manage_tasks_path, notice: "Task reactivated."
    end

    private

    def load_form_collections
      @task_lists = TaskList.active.ordered
    end

    # The edit page is reached from three trees, and the back arrow + post-save
    # redirect must return the user to the one they actually came from:
    #
    #   • Settings → Manage tasks → Edit task          → back to the management index
    #   • Work surface → occurrence detail → Edit task  → back to that occurrence
    #   • Follow-up → "Tasks spawned" → the task        → back to that follow-up
    #
    # The occurrence's "Edit task" link carries origin=occurrence (+ the
    # occurrence id); the follow-up's spawned-task link carries
    # origin=follow_up (+ the follow_up id), so each cross-tree jump resolves
    # back to where it started instead of stranding the manager deep in
    # Settings. Mirrors TaskListsController#resolve_edit_back_target and
    # OccurrencesController#resolve_back_target.
    def resolve_edit_back_target(task)
      if (occurrence = origin_occurrence(task))
        [ tasks_occurrence_path(occurrence), occurrence.snapshot_title ]
      elsif (follow_up = origin_follow_up(task))
        [ follow_up_path(follow_up), follow_up.title ]
      else
        [ tasks_manage_tasks_path, "Tasks" ]
      end
    end

    # Saving from a cross-tree entry returns the user there — the same place the
    # back arrow resolves to — rather than the Settings index.
    def after_update_path(task)
      if (occurrence = origin_occurrence(task))
        tasks_occurrence_path(occurrence)
      elsif (follow_up = origin_follow_up(task))
        follow_up_path(follow_up)
      else
        tasks_manage_tasks_path
      end
    end

    # Only honor origin=occurrence when the referenced occurrence really belongs
    # to this task, so a hand-edited query string can't point the back target at
    # an unrelated page.
    def origin_occurrence(task)
      return nil unless params[:origin] == "occurrence" && params[:occurrence_id].present?

      task.task_occurrences.find_by(id: params[:occurrence_id])
    end

    # Only honor origin=follow_up when the referenced follow-up actually spawned
    # this task, so a hand-edited query string can't point the back target at an
    # unrelated follow-up.
    def origin_follow_up(task)
      return nil unless params[:origin] == "follow_up" && params[:follow_up_id].present?

      FollowUp.joins(:task_links).find_by(id: params[:follow_up_id], task_links: { task_id: task.id })
    end

    def task_params
      permitted = params.require(:task).permit(
        :task_list_id,
        :title,
        :instructions,
        :position,
        :active,
        :requires_photo_evidence,
        :recurrence_type,
        :starts_on,
        :ends_on,
        :due_time,
        :one_time_on,
        weekdays: []
      )
      permitted[:weekdays] = Array(permitted[:weekdays]).reject(&:blank?).map(&:to_i)
      permitted[:requires_photo_evidence] = permitted[:requires_photo_evidence] == "1"
      permitted
    end

    def refresh_open_occurrences(task)
      OccurrenceBuilder.new.build!(
        from: Time.zone.today,
        to: [ Time.zone.today.end_of_month, task.ends_on ].compact.min
      )
    end

    def after_create_path
      params[:return_to] == "dashboard" ? tasks_root_path : tasks_manage_tasks_path
    end
  end
end
