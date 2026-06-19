class AddAiReviewToPhotoAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :photo_assets, :reviewed_via, :string
    add_column :photo_assets, :treatment_instructions, :text
    add_column :photo_assets, :treated_at, :datetime
  end
end
