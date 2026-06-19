class CreatePhotoAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :photo_assets do |t|
      t.string     :status, null: false, default: "unreviewed"
      t.string     :caption
      t.text       :notes
      t.references :uploaded_by, null: true, foreign_key: { to_table: :users }
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.datetime   :reviewed_at
      t.timestamps
    end

    add_index :photo_assets, :status
  end
end
