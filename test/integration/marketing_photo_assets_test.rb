require "test_helper"

class MarketingPhotoAssetsTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  test "employee without the marketing module is redirected away" do
    sign_in_as(users(:two))
    get photo_assets_path
    assert_redirected_to root_path
  end

  test "employee with the marketing module can open the library" do
    employee = users(:two)
    employee.grant_module("marketing")
    sign_in_as(employee)

    get photo_assets_path
    assert_response :success
  end

  test "uploading library photos and a camera photo creates one asset each" do
    sign_in_as(users(:one))

    assert_difference "PhotoAsset.count", 3 do
      post photo_assets_path, params: {
        photo_asset: {
          photos: [ sample_upload, sample_upload ],
          camera_photo: sample_upload
        }
      }
    end

    assert_redirected_to photo_assets_path
    assert_equal users(:one), PhotoAsset.last.uploaded_by
    assert_equal "pending", PhotoAsset.last.status
  end

  test "submitting no photos re-renders the form with an alert" do
    sign_in_as(users(:one))

    assert_no_difference "PhotoAsset.count" do
      post photo_assets_path, params: { photo_asset: { photos: [ "" ] } }
    end
    assert_redirected_to new_photo_asset_path
  end

  test "the photo page renders suggestions and applied tags" do
    sign_in_as(users(:one))
    asset = create_asset
    asset.taggings.create!(tag: tags(:food), source: "ai") # pending suggestion
    asset.taggings.create!(tag: tags(:product), source: "manual", confirmed_at: Time.current)

    get photo_asset_path(asset)
    assert_response :success
    assert_select ".suggestion-row", 1
    assert_select ".tag-chip-list li", 1
  end

  test "the photo page offers unapplied active tags to add by hand" do
    sign_in_as(users(:one))
    asset = create_asset

    get photo_asset_path(asset)
    assert_response :success
    assert_select "form.tag-add"
    # Active vocabulary is selectable; the inactive tag is not.
    assert_select "form.tag-add option", text: tags(:food).name
    assert_select "form.tag-add option", text: tags(:inactive_promo).name, count: 0
  end

  test "the add-photos page renders" do
    sign_in_as(users(:one))
    get new_photo_asset_path
    assert_response :success
  end

  test "saving caption and notes updates the asset" do
    sign_in_as(users(:one))
    asset = create_asset

    patch photo_asset_path(asset), params: { photo_asset: { caption: "Front counter bagels", notes: "Morning light." } }

    asset.reload
    assert_equal "Front counter bagels", asset.caption
    assert_equal "Morning light.", asset.notes
  end

  test "adding a tag by hand files the photo as tagged" do
    sign_in_as(users(:one))
    asset = create_asset

    assert_difference "asset.taggings.count", 1 do
      post photo_asset_taggings_path(asset), params: { tag_id: tags(:food).id }
    end

    tagging = asset.taggings.sole
    assert_equal "manual", tagging.source
    assert tagging.confirmed?
    assert_equal "tagged", asset.reload.status
  end

  test "confirming an AI suggestion moves the photo to tagged" do
    sign_in_as(users(:one))
    asset = create_asset
    suggestion = asset.taggings.create!(tag: tags(:food), source: "ai")
    assert_equal "needs_review", asset.reload.status

    patch confirm_photo_asset_tagging_path(asset, suggestion)

    assert suggestion.reload.confirmed?
    assert_equal "tagged", asset.reload.status
  end

  test "dismissing a suggestion removes the tagging" do
    sign_in_as(users(:one))
    asset = create_asset
    suggestion = asset.taggings.create!(tag: tags(:food), source: "ai")

    assert_difference "asset.taggings.count", -1 do
      delete photo_asset_tagging_path(asset, suggestion)
    end
    assert_equal "pending", asset.reload.status
  end

  test "the library wires up select mode on every card" do
    sign_in_as(users(:one))
    create_asset

    get photo_assets_path
    assert_response :success
    # The select-mode toggle and the per-card tap handler are what let a tap
    # select instead of opening, so a stray tap can't wipe a built-up selection.
    assert_select "button[data-photo-select-target=toggle]", text: "Select"
    assert_select "form[data-action=?]", "turbo:submit-start->photo-select#reset"
    assert_select "a.photo-card[data-action=?]", "photo-select#card"
  end

  test "library ZIP downloads open in a new context so the standalone PWA can't trap the user" do
    sign_in_as(users(:one))
    create_asset

    get photo_assets_path
    assert_response :success
    # A same-window nav to the attachment response strands the standalone PWA
    # on a chrome-less Quick Look page; target=_blank hands it an escapable view.
    assert_select 'a[href^=?][target="_blank"]', photo_asset_exports_path, count: 1
    assert_select 'button[formaction=?][formtarget="_blank"]', photo_asset_exports_path, count: 1
  end

  test "filtering the library by tag shows only matching photos" do
    sign_in_as(users(:one))
    tagged = create_asset
    tagged.taggings.create!(tag: tags(:food), source: "manual", confirmed_at: Time.current)
    create_asset # untagged

    get photo_assets_path(tag: "food")
    assert_response :success
    assert_select "a.photo-card", 1
  end

  test "deleting a photo removes it from the library" do
    sign_in_as(users(:one))
    asset = create_asset

    assert_difference "PhotoAsset.count", -1 do
      delete photo_asset_path(asset)
    end
    assert_redirected_to photo_assets_path
  end

  private

  def sample_upload
    fixture_file_upload("photo_asset_sample.png", "image/png")
  end

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
