class AddDisplayWindowToTaskLists < ActiveRecord::Migration[8.1]
  def change
    add_column :task_lists, :display_start_time, :time
    add_column :task_lists, :display_end_time, :time
  end
end
