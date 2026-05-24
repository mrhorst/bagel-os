class CreateFollowUps < ActiveRecord::Migration[8.1]
  def change
    create_table :follow_ups do |t|
      # Polymorphic origin — what surface raised this follow-up. Today only
      # LogBookResponse, but the column shape is ready for future sources
      # (NormalizationReview, manual, …).
      t.references :origin, polymorphic: true, null: true

      t.string  :title,           null: false
      t.text    :description
      t.string  :urgency,         null: false, default: "normal"
      t.string  :status,          null: false, default: "open"

      t.references :opened_by,    null: true, foreign_key: { to_table: :users }
      t.datetime   :opened_at,    null: false

      t.references :resolved_by,  null: true, foreign_key: { to_table: :users }
      t.datetime   :resolved_at
      t.text       :resolution_note
      t.string     :resolved_via

      t.timestamps
    end

    add_index :follow_ups, :status
    add_index :follow_ups, :urgency
  end
end
