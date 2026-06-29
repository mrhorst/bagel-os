require "test_helper"

# Every home-dashboard surface card whose summary interpolates a review count
# must agree in number: one item needing attention reads "1 link to verify",
# not "1 links to verify". The Log Book and Review Queue cards already use
# pluralize (the latter via #336); the Order guides, Inventory, Products, and
# Marketing cards were missed and read ungrammatically whenever exactly one
# record was waiting — the count a real backlog passes through on its way to
# zero. This locks all four to the same convention.
class HomeDashboardSurfacePluralizationTest < ActionDispatch::IntegrationTest
  test "the order guides card reads in the singular for one link" do
    create_guide_items(1)

    get root_path

    assert_response :success
    assert_summary order_guides_path, "1 link to verify"
  end

  test "the order guides card reads in the plural for several links" do
    create_guide_items(2)

    get root_path

    assert_summary order_guides_path, "2 links to verify"
  end

  test "the inventory card reads in the singular for one item" do
    create_inventory_items(1)

    get root_path

    assert_response :success
    assert_summary inventory_path, "1 item to clean up"
  end

  test "the products card reads in the singular for one record" do
    create_products(1)

    get root_path

    assert_response :success
    assert_summary products_path, "1 record to clean up"
  end

  test "the marketing card reads in the singular for one photo" do
    create_review_photos(1)

    get root_path

    assert_response :success
    assert_summary photo_assets_path, "1 photo to review"
  end

  private

  def assert_summary(path, text)
    assert_select "a[href=?] .home-surface-card-summary", path, text: text
  end

  def create_guide_items(count)
    import = OrderGuideImport.create!(
      source_filename: "plural-probe.csv", guide_type: "daily",
      file_checksum: "plural-probe-#{SecureRandom.hex(8)}",
      imported_at: Time.current, status: "imported"
    )
    count.times do |i|
      import.order_guide_items.create!(
        guide_type: "daily", section_name: "Produce",
        item_name: "Item #{i}", raw_line: "raw #{i}",
        active: true, needs_review: true
      )
    end
  end

  def create_inventory_items(count)
    count.times do |i|
      InventoryItem.create!(
        name: "Item #{i}", key: "plural-probe-#{SecureRandom.hex(6)}",
        guide_frequency: "daily", active: true, needs_review: true
      )
    end
  end

  def create_products(count)
    supplier = Supplier.create!(name: "Plural Probe Supplier #{SecureRandom.hex(4)}")
    count.times do |i|
      supplier.products.create!(
        canonical_name: "Product #{i}", active: true, needs_review: true
      )
    end
  end

  def create_review_photos(count)
    count.times do
      PhotoAsset.new.tap do |asset|
        asset.photo.attach(
          io: file_fixture("photo_asset_sample.png").open,
          filename: "sample.png", content_type: "image/png"
        )
        asset.save!
        asset.update_column(:status, "needs_review")
      end
    end
  end
end
