class CreateCollectionMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_memberships do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :photo_asset, null: false, foreign_key: true
      t.integer    :position, null: false, default: 0
      t.integer    :added_by_id

      t.timestamps
    end

    add_index :collection_memberships, %i[collection_id photo_asset_id], unique: true
    add_index :collection_memberships, :added_by_id
  end
end
