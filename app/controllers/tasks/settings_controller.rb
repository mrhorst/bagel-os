module Tasks
  # /tasks/manage — the settings hub. Three cards link out to the three
  # things you can configure: tasks, lists, staff. Everything else lives
  # under /tasks/manage/<thing>.
  class SettingsController < ApplicationController
    def index
      @task_count     = Task.active.count
      @list_count     = TaskList.active.count
      @staff_count    = StaffMember.active.count
      @inactive_tasks = Task.where(active: false).count
      @inactive_lists = TaskList.where(active: false).count
      @inactive_staff = StaffMember.where(active: false).count
    end
  end
end
