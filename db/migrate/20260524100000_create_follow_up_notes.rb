class CreateFollowUpNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :follow_up_notes do |t|
      t.references :follow_up, null: false, foreign_key: true
      t.references :author,    null: true,  foreign_key: { to_table: :users }
      t.text       :body,      null: false
      t.timestamps
    end
  end
end
