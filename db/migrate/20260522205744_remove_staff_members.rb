class RemoveStaffMembers < ActiveRecord::Migration[8.1]
  # Drops the StaffMember model and its FK columns on task_completions.
  # The display name of who completed each task is preserved in the existing
  # snapshot_staff_name / snapshot_undone_by_staff_name text columns, so
  # historical "Completed by Maria" lines still render after this.
  def change
    remove_foreign_key :task_completions, column: :staff_member_id, to_table: :staff_members
    remove_foreign_key :task_completions, column: :undone_by_staff_member_id, to_table: :staff_members
    remove_index :task_completions, name: "index_task_completions_on_staff_member_id"
    remove_index :task_completions, name: "index_task_completions_on_undone_by_staff_member_id"
    remove_column :task_completions, :staff_member_id, :integer
    remove_column :task_completions, :undone_by_staff_member_id, :integer

    drop_table :staff_members do |t|
      t.boolean :active, default: true, null: false
      t.datetime :created_at, null: false
      t.string :display_name, null: false
      t.string :notes
      t.datetime :updated_at, null: false
      t.index [ :active, :display_name ], name: "index_staff_members_on_active_and_display_name"
    end
  end
end
