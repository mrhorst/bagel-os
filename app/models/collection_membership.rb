class CollectionMembership < ApplicationRecord
  belongs_to :collection
  belongs_to :photo_asset
  belongs_to :added_by, class_name: "User", optional: true

  validates :photo_asset_id, uniqueness: { scope: :collection_id }
end
