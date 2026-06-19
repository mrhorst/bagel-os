require "test_helper"

class MarketingPostReadyTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  test "employee without the marketing module cannot crop" do
    sign_in_as(users(:two))
    asset = create_asset(real: true)
    get crop_photo_asset_path(asset, style: "square")
    assert_redirected_to root_path
  end

  test "downloads a square social crop as a jpeg" do
    sign_in_as(users(:one))
    asset = create_asset(real: true)

    get crop_photo_asset_path(asset, style: "square")
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_match(/photo-#{asset.id}-square\.jpg/, response.headers["Content-Disposition"])
  end

  test "supports story and wide crops too" do
    sign_in_as(users(:one))
    asset = create_asset(real: true)

    %w[story wide].each do |style|
      get crop_photo_asset_path(asset, style: style)
      assert_response :success
      assert_equal "image/jpeg", response.media_type
    end
  end

  test "download links open in a new context so the standalone PWA can't trap the user" do
    sign_in_as(users(:one))
    asset = create_asset(real: true)

    get photo_asset_path(asset)
    assert_response :success

    # Without target=_blank, a same-window navigation to these attachment
    # downloads strands the standalone PWA on a chrome-less Quick Look page.
    %w[square story wide].each do |style|
      assert_select %(a[href="#{crop_photo_asset_path(asset, style: style)}"][target="_blank"]), count: 1
    end
    assert_select %(a[href="#{rails_blob_path(asset.photo, disposition: "attachment")}"][target="_blank"]), count: 1
  end

  test "an unknown crop style 404s" do
    sign_in_as(users(:one))
    asset = create_asset(real: true)
    get crop_photo_asset_path(asset, style: "billboard")
    assert_response :not_found
  end

  test "describe is rejected when the gateway isn't configured" do
    sign_in_as(users(:one))
    asset = create_asset

    assert_no_enqueued_jobs do
      post describe_photo_asset_path(asset)
    end
    assert_redirected_to photo_asset_path(asset)
    assert_equal "AI copy isn't set up for this install yet.", flash[:alert]
  end

  test "applying a suggested caption copies it onto the photo" do
    sign_in_as(users(:one))
    asset = create_asset
    asset.update!(suggested_caption: "Golden and warm.", described_at: Time.current)

    patch photo_asset_path(asset), params: { photo_asset: { caption: asset.suggested_caption } }
    assert_equal "Golden and warm.", asset.reload.caption
  end

  test "saving alt text and hashtags updates the photo" do
    sign_in_as(users(:one))
    asset = create_asset

    patch photo_asset_path(asset), params: { photo_asset: { alt_text: "A bagel sandwich", hashtags: "#bagel" } }
    asset.reload
    assert_equal "A bagel sandwich", asset.alt_text
    assert_equal "#bagel", asset.hashtags
  end

  private

  def create_asset(real: false)
    file = real ? "photo_asset_real.png" : "photo_asset_sample.png"
    PhotoAsset.new.tap do |asset|
      asset.photo.attach(
        io: file_fixture(file).open,
        filename: file,
        content_type: "image/png"
      )
      asset.save!
    end
  end
end
