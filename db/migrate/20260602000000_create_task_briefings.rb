class CreateTaskBriefings < ActiveRecord::Migration[8.1]
  def change
    create_table :task_briefings do |t|
      t.string :scope_type, null: false, default: "tasks_dashboard"
      t.string :scope_key, null: false, default: "today"
      t.datetime :generated_at, null: false
      t.datetime :stale_after
      t.string :input_digest, null: false
      t.string :headline, null: false
      t.text :next_action, null: false
      t.json :priority_items, null: false, default: []
      t.json :source_task_occurrence_ids, null: false, default: []

      t.timestamps
    end

    add_index :task_briefings, [ :scope_type, :scope_key ], unique: true
    add_index :task_briefings, :generated_at
  end
end
