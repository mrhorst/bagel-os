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
    end

    def update
      @task = Task.find(params[:id])

      if @task.update(task_params)
        refresh_open_occurrences(@task)
        LiveUpdates.task_state_changed!
        redirect_to tasks_manage_tasks_path, notice: "Task updated."
      else
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
