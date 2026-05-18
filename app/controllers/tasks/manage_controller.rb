module Tasks
  class ManageController < ApplicationController
    before_action :load_form_collections, only: %i[index create update]

    def index
      @tasks = Task.joins(:task_list).includes(:task_list).order("task_lists.position ASC", "tasks.position ASC", "tasks.title ASC")
      @task = Task.new(recurrence_type: "daily", starts_on: Time.zone.today)
    end

    def create
      task = Task.new(task_params)

      if task.save
        redirect_to tasks_manage_path, notice: "Task created."
      else
        redirect_to tasks_manage_path, alert: task.errors.full_messages.to_sentence
      end
    end

    def update
      task = Task.find(params[:id])

      if task.update(task_params)
        refresh_open_occurrences(task)
        redirect_to tasks_manage_path, notice: "Task updated."
      else
        redirect_to tasks_manage_path, alert: task.errors.full_messages.to_sentence
      end
    end

    def archive
      Task.find(params[:id]).archive!
      redirect_to tasks_manage_path, notice: "Task archived."
    end

    def reactivate
      Task.find(params[:id]).reactivate!
      redirect_to tasks_manage_path, notice: "Task reactivated."
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
  end
end
