class CreateLogBookTables < ActiveRecord::Migration[8.1]
  def change
    create_table :log_book_sections do |t|
      t.string :title, null: false
      t.text :description
      t.string :section_type, null: false
      t.integer :position, null: false, default: 0
      t.boolean :required, null: false, default: false
      t.boolean :allow_no_note, null: false, default: true
      t.string :unit_label
      t.boolean :active, null: false, default: true
      t.references :created_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :log_book_sections, :active
    add_index :log_book_sections, [ :position, :title ]

    create_table :log_book_entries do |t|
      t.date :operating_date, null: false
      t.references :submitted_by, foreign_key: { to_table: :users }
      t.datetime :submitted_at

      t.timestamps
    end

    add_index :log_book_entries, :operating_date, unique: true

    create_table :log_book_responses do |t|
      t.references :log_book_entry, null: false, foreign_key: true
      t.references :log_book_section, null: false, foreign_key: true
      t.string :section_title_snapshot, null: false
      t.string :section_type_snapshot, null: false
      t.text :value_text
      t.decimal :value_number, precision: 12, scale: 3
      t.boolean :no_note, null: false, default: false
      t.boolean :flagged_for_follow_up, null: false, default: false
      t.string :urgency, null: false, default: "normal"
      t.datetime :follow_up_resolved_at
      t.references :follow_up_resolved_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :log_book_responses, [ :log_book_entry_id, :log_book_section_id ],
      unique: true,
      name: "index_log_book_responses_on_entry_and_section"
    add_index :log_book_responses, [ :flagged_for_follow_up, :follow_up_resolved_at ],
      name: "index_log_book_responses_on_follow_up_status"
  end
end
