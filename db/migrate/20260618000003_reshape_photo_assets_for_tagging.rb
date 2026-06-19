class ReshapePhotoAssetsForTagging < ActiveRecord::Migration[8.1]
  # The marketing module pivots from AI photo *review/treatment* to an asset
  # library with AI-assisted *tagging*. Drop the review/treatment columns and
  # add a timestamp marking when the tagging pass last ran.
  def change
    remove_column :photo_assets, :reviewed_at, :datetime
    remove_column :photo_assets, :reviewed_by_id, :integer
    remove_column :photo_assets, :reviewed_via, :string
    remove_column :photo_assets, :treated_at, :datetime
    remove_column :photo_assets, :treatment_instructions, :text

    add_column :photo_assets, :ai_tagged_at, :datetime

    change_column_default :photo_assets, :status, from: "unreviewed", to: "pending"
  end
end
