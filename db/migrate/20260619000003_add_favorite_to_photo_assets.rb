class AddFavoriteToPhotoAssets < ActiveRecord::Migration[8.1]
  # A quick curation flag so the team's best/approved "hero" shots float to the
  # top of the library, independent of the tagging lifecycle.
  def change
    add_column :photo_assets, :favorite, :boolean, null: false, default: false
    add_index :photo_assets, :favorite
  end
end
