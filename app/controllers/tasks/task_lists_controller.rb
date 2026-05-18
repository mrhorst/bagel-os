module Tasks
  class TaskListsController < ApplicationController
    def index
      @task_lists = TaskList.ordered
      @next_position = TaskList.maximum(:position).to_i + 1
    end

    def create
      task_list = TaskList.new(task_list_params)
      task_list.position = TaskList.maximum(:position).to_i + 1 if task_list.position.zero?

      if task_list.save
        redirect_to tasks_lists_path, notice: "Task list created."
      else
        redirect_to tasks_lists_path, alert: task_list.errors.full_messages.to_sentence
      end
    end

    def update
      task_list = TaskList.find(params[:id])

      if task_list.update(task_list_params)
        redirect_to tasks_lists_path, notice: "Task list updated."
      else
        redirect_to tasks_lists_path, alert: task_list.errors.full_messages.to_sentence
      end
    end

    def archive
      TaskList.find(params[:id]).archive!
      redirect_to tasks_lists_path, notice: "Task list archived."
    end

    def reactivate
      TaskList.find(params[:id]).reactivate!
      redirect_to tasks_lists_path, notice: "Task list reactivated."
    end

    private

    def task_list_params
      params.require(:task_list).permit(:name, :position, :notes, :display_start_time, :display_end_time)
    end
  end
end
