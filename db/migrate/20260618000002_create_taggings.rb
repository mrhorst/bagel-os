class CreateTaggings < ActiveRecord::Migration[8.1]
  def change
    create_table :taggings do |t|
      t.references :photo_asset, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.string     :source, null: false, default: "manual"
      t.datetime   :confirmed_at
      t.integer    :created_by_id

      t.timestamps
    end

    add_index :taggings, %i[photo_asset_id tag_id], unique: true
    add_index :taggings, :created_by_id
  end
end
