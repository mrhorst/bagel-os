class AddAiDescriptionToPhotoAssets < ActiveRecord::Migration[8.1]
  # AI-drafted marketing copy for a photo. Kept separate from the human-owned
  # caption so generating never overwrites an edit — staff opt in by applying
  # the suggestion. alt_text and hashtags are AI-fillable but human-editable.
  def change
    add_column :photo_assets, :suggested_caption, :text
    add_column :photo_assets, :hashtags, :text
    add_column :photo_assets, :alt_text, :string
    add_column :photo_assets, :described_at, :datetime
  end
end
