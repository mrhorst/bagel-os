module Tasks
  # /tasks/manage — the settings hub. Two cards link out to the two things
  # you can configure: tasks and lists. Everything else lives under
  # /tasks/manage/<thing>.
  class SettingsController < ApplicationController
    def index
      @task_count     = Task.active.count
      @list_count     = TaskList.active.count
      @inactive_tasks = Task.where(active: false).count
      @inactive_lists = TaskList.where(active: false).count
    end
  end
end
