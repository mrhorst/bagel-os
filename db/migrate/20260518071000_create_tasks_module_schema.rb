class CreateTasksModuleSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_members do |t|
      t.string :display_name, null: false
      t.boolean :active, null: false, default: true
      t.text :notes

      t.timestamps
    end
    add_index :staff_members, [ :active, :display_name ]

    create_table :task_lists do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.text :notes

      t.timestamps
    end
    add_index :task_lists, :key, unique: true
    add_index :task_lists, [ :active, :position ]

    create_table :tasks do |t|
      t.references :task_list, null: false, foreign_key: true
      t.string :title, null: false
      t.text :instructions
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.boolean :requires_photo_evidence, null: false, default: false
      t.string :recurrence_type, null: false
      t.date :starts_on
      t.date :ends_on
      t.time :due_time
      t.json :weekdays, null: false, default: []
      t.date :one_time_on

      t.timestamps
    end
    add_index :tasks, [ :task_list_id, :active, :position ]
    add_index :tasks, :recurrence_type

    create_table :task_occurrences do |t|
      t.references :task, null: false, foreign_key: true
      t.references :task_list, null: false, foreign_key: true
      t.string :period_kind, null: false
      t.date :period_starts_on, null: false
      t.date :period_ends_on, null: false
      t.datetime :due_at
      t.datetime :completion_window_ends_at
      t.string :snapshot_title, null: false
      t.text :snapshot_instructions
      t.string :snapshot_list_name, null: false
      t.boolean :requires_photo_evidence, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :task_occurrences,
      [ :task_id, :period_kind, :period_starts_on ],
      unique: true,
      name: :idx_task_occurrences_unique_period
    add_index :task_occurrences, [ :period_kind, :period_starts_on, :period_ends_on ], name: :idx_task_occurrences_period
    add_index :task_occurrences, :completion_window_ends_at
    add_index :task_occurrences, :due_at

    create_table :task_completions do |t|
      t.references :task_occurrence, null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: true
      t.string :snapshot_staff_name, null: false
      t.datetime :completed_at, null: false
      t.text :notes
      t.datetime :undone_at
      t.text :undone_note
      t.references :undone_by_staff_member, foreign_key: { to_table: :staff_members }
      t.string :snapshot_undone_by_staff_name

      t.timestamps
    end
    add_index :task_completions,
      :task_occurrence_id,
      unique: true,
      where: "undone_at IS NULL",
      name: :idx_task_completions_one_active
    add_index :task_completions, :undone_at
  end
end
