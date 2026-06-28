require "test_helper"

class PhotoAssetBulkActionsControllerTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  test "employee without the marketing module is turned away" do
    sign_in_as(users(:two))
    post bulk_actions_photo_assets_path, params: { bulk_action: "favorite", photo_asset_ids: [] }
    assert_redirected_to root_path
  end

  test "favoriting selected photos stars them all" do
    sign_in_as(users(:one))
    a, b = create_asset, create_asset

    post bulk_actions_photo_assets_path, params: { bulk_action: "favorite", photo_asset_ids: [ a.id, b.id ] }

    assert a.reload.favorite?
    assert b.reload.favorite?
  end

  test "unfavoriting clears the star" do
    sign_in_as(users(:one))
    asset = create_asset
    asset.update_column(:favorite, true)

    post bulk_actions_photo_assets_path, params: { bulk_action: "unfavorite", photo_asset_ids: [ asset.id ] }
    assert_not asset.reload.favorite?
  end

  test "deleting selected photos removes them" do
    sign_in_as(users(:one))
    a, b = create_asset, create_asset

    assert_difference "PhotoAsset.count", -2 do
      post bulk_actions_photo_assets_path, params: { bulk_action: "delete", photo_asset_ids: [ a.id, b.id ] }
    end
  end

  test "tagging selected photos applies a confirmed tag to each" do
    sign_in_as(users(:one))
    a, b = create_asset, create_asset

    post bulk_actions_photo_assets_path, params: { bulk_action: "add_tag", tag_id: tags(:food).id, photo_asset_ids: [ a.id, b.id ] }

    [ a, b ].each do |asset|
      tagging = asset.taggings.sole
      assert_equal "manual", tagging.source
      assert tagging.confirmed?
      assert_equal "tagged", asset.reload.status
    end
  end

  test "adding selected photos to a collection creates one membership each" do
    sign_in_as(users(:one))
    a, b = create_asset, create_asset

    assert_difference "CollectionMembership.count", 2 do
      post bulk_actions_photo_assets_path, params: { bulk_action: "add_to_collection", collection_id: collections(:summer).id, photo_asset_ids: [ a.id, b.id ] }
    end
  end

  test "adding to a collection twice does not duplicate memberships" do
    sign_in_as(users(:one))
    asset = create_asset
    collections(:summer).collection_memberships.create!(photo_asset: asset)

    assert_no_difference "CollectionMembership.count" do
      post bulk_actions_photo_assets_path, params: { bulk_action: "add_to_collection", collection_id: collections(:summer).id, photo_asset_ids: [ asset.id ] }
    end
  end

  test "adding to a collection reports the number actually added, not the number selected" do
    sign_in_as(users(:one))
    already_in, fresh = create_asset, create_asset
    collections(:summer).collection_memberships.create!(photo_asset: already_in)

    post bulk_actions_photo_assets_path, params: { bulk_action: "add_to_collection", collection_id: collections(:summer).id, photo_asset_ids: [ already_in.id, fresh.id ] }

    # Only `fresh` is a new membership; the notice must count that one, not both.
    assert_nil flash[:alert]
    assert_match(/Added 1 photo to/, flash[:notice])
  end

  test "adding only already-present photos says so instead of claiming a fresh add" do
    sign_in_as(users(:one))
    asset = create_asset
    collections(:summer).collection_memberships.create!(photo_asset: asset)

    post bulk_actions_photo_assets_path, params: { bulk_action: "add_to_collection", collection_id: collections(:summer).id, photo_asset_ids: [ asset.id ] }

    assert_nil flash[:alert]
    assert_no_match(/Added 1 photo/, flash[:notice])
    assert_match(/already in/, flash[:notice])
  end

  test "tagging reports the number actually tagged, not the number selected" do
    sign_in_as(users(:one))
    already_tagged, fresh = create_asset, create_asset
    already_tagged.taggings.create!(tag: tags(:food), source: "manual", confirmed_at: Time.current, created_by: users(:one))

    post bulk_actions_photo_assets_path, params: { bulk_action: "add_tag", tag_id: tags(:food).id, photo_asset_ids: [ already_tagged.id, fresh.id ] }

    # Only `fresh` gains the tag; the notice must count that one, not both.
    assert_nil flash[:alert]
    assert_match(/Tagged 1 photo/, flash[:notice])
  end

  test "tagging only already-tagged photos says so instead of claiming a fresh tag" do
    sign_in_as(users(:one))
    asset = create_asset
    asset.taggings.create!(tag: tags(:food), source: "manual", confirmed_at: Time.current, created_by: users(:one))

    post bulk_actions_photo_assets_path, params: { bulk_action: "add_tag", tag_id: tags(:food).id, photo_asset_ids: [ asset.id ] }

    assert_nil flash[:alert]
    assert_no_match(/Tagged 1 photo/, flash[:notice])
    assert_match(/already have/, flash[:notice])
  end

  test "bulk tagging confirms a pending suggestion and counts it as tagged" do
    sign_in_as(users(:one))
    asset = create_asset
    asset.taggings.create!(tag: tags(:food), source: "ai", confirmed_at: nil)

    post bulk_actions_photo_assets_path, params: { bulk_action: "add_tag", tag_id: tags(:food).id, photo_asset_ids: [ asset.id ] }

    # Confirming a pending suggestion is a real change — it counts.
    assert asset.taggings.sole.confirmed?
    assert_nil flash[:alert]
    assert_match(/Tagged 1 photo/, flash[:notice])
  end

  test "applying with no tag chosen warns via alert, not a success notice" do
    sign_in_as(users(:one))
    asset = create_asset

    post bulk_actions_photo_assets_path, params: { bulk_action: "add_tag", tag_id: "", photo_asset_ids: [ asset.id ] }

    assert_equal "Choose a tag to apply.", flash[:alert]
    assert_nil flash[:notice]
    assert_empty asset.reload.taggings
  end

  test "adding to collection with none chosen warns via alert, not a success notice" do
    sign_in_as(users(:one))
    asset = create_asset

    assert_no_difference "CollectionMembership.count" do
      post bulk_actions_photo_assets_path, params: { bulk_action: "add_to_collection", collection_id: "", photo_asset_ids: [ asset.id ] }
    end

    assert_equal "Choose a collection.", flash[:alert]
    assert_nil flash[:notice]
  end

  test "a successful tag reports success via notice" do
    sign_in_as(users(:one))
    asset = create_asset

    post bulk_actions_photo_assets_path, params: { bulk_action: "add_tag", tag_id: tags(:food).id, photo_asset_ids: [ asset.id ] }

    assert_nil flash[:alert]
    assert_match(/Tagged/, flash[:notice])
  end

  test "an empty selection is rejected with an alert" do
    sign_in_as(users(:one))
    post bulk_actions_photo_assets_path, params: { bulk_action: "favorite", photo_asset_ids: [] }
    assert_redirected_to photo_assets_path
    assert_equal "Select at least one photo first.", flash[:alert]
  end

  test "an unknown action is rejected" do
    sign_in_as(users(:one))
    asset = create_asset
    post bulk_actions_photo_assets_path, params: { bulk_action: "nuke", photo_asset_ids: [ asset.id ] }
    assert_equal "That bulk action isn't available.", flash[:alert]
  end

  private

  def create_asset
    PhotoAsset.new.tap do |asset|
      asset.photo.attach(
        io: file_fixture("photo_asset_sample.png").open,
        filename: "sample.png",
        content_type: "image/png"
      )
      asset.save!
    end
  end
end
