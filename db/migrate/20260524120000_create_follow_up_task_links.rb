class CreateFollowUpTaskLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :follow_up_task_links do |t|
      t.references :follow_up,  null: false, foreign_key: true
      t.references :task,       null: false, foreign_key: true
      # one_shot | recurring — matches the user's spawn choice; recorded so
      # we can render history accurately even if the task changes later.
      t.string     :link_kind,  null: false, default: "one_shot"
      t.references :created_by, null: true,  foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :follow_up_task_links, %i[follow_up_id task_id], unique: true
  end
end
