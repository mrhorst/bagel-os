class AddUserToTaskCompletions < ActiveRecord::Migration[8.1]
  def change
    # New columns are nullable: existing rows still reference staff_member only.
    add_reference :task_completions, :user, null: true, foreign_key: true
    add_reference :task_completions, :undone_by_user, null: true,
                                                       foreign_key: { to_table: :users }

    # New rows from now on use user_id, so staff_member can be empty.
    change_column_null :task_completions, :staff_member_id, true
  end
end
