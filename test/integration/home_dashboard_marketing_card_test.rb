require "test_helper"

# The home "Marketing" surface card must mirror the photo library's own notion
# of review work: it counts photos in the real `needs_review` status (AI-tagged,
# awaiting a human). Previously it queried a non-existent "unreviewed" status, so
# it always counted zero and told the user "Library is reviewed" even when photos
# were waiting — a KPI that lied on every dashboard load.
class HomeDashboardMarketingCardTest < ActionDispatch::IntegrationTest
  test "the marketing card counts photos that actually need review" do
    2.times { create_review_photo("needs_review") }
    create_review_photo("tagged") # a reviewed photo must not inflate the count

    get root_path

    assert_response :success
    assert_select "a[href=?] .home-surface-card-summary", photo_assets_path,
      text: "2 photos to review"
    assert_select "a.home-surface-card-active[href=?]", photo_assets_path
  end

  test "the marketing card reads as reviewed when nothing needs review" do
    create_review_photo("tagged")

    get root_path

    assert_response :success
    assert_select "a[href=?] .home-surface-card-summary", photo_assets_path,
      text: "Library is reviewed"
    assert_select "a.home-surface-card-active[href=?]", photo_assets_path, count: 0
  end

  private

  def create_review_photo(status)
    PhotoAsset.new.tap do |asset|
      asset.photo.attach(
        io: file_fixture("photo_asset_sample.png").open,
        filename: "sample.png",
        content_type: "image/png"
      )
      asset.save!
      asset.update_column(:status, status)
    end
  end
end
