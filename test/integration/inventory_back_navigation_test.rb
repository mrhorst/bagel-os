require "test_helper"

# The Inventory module's sub-pages — the per-guide Buy List (shopping_list) and
# the Counts history — are reached from the Inventory index and send their
# mobile top-left chevron "up one level" to Inventory. But neither page exposed
# any in-content desktop control back to Inventory: the page-heading held only
# forward/sideways actions ("Start count", "Guide setup", "New count"). On a
# wide screen (no mobile header) the only way back was the global sidebar's
# "Inventory" item, which renders as the *active* entry on these pages — so a
# user had to click the already-active nav item to "go back". Every sibling
# detail page (Order Guides → "All guides", Imports → "All imports",
# Collections → "Back to library") mirrors its mobile chevron with a
# desktop-visible control; these assert the two Inventory sub-pages now do too,
# without disturbing the mobile chevron.
class InventoryBackNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @guide = OrderGuide.create!(name: "Weekly")
    section = @guide.section_named!("Walk-in")
    item = InventoryItem.create!(name: "Cream Cheese", count_unit: "tub")
    item.add_to_order_guide!(
      @guide,
      order_guide_section: section,
      tracking_mode: "counted",
      expected_usage_quantity: 4,
      buffer_quantity: 1
    )
    InventoryCount.create!(
      order_guide: @guide, source: "manual", status: "completed",
      counted_at: Time.current, completed_at: Time.current
    )
  end

  # Strip the chrome that is hidden on desktop (the mobile screen header) and the
  # always-present global sidebar, so what's left is the in-content page body a
  # wide-screen user navigates by.
  def in_content_links_to(path)
    doc = Nokogiri::HTML(response.body)
    doc.css(".mobile-screen-header, .app-sidebar").remove
    doc.css("a").select { |a| a["href"] == path }
  end

  test "the buy list offers a desktop-visible way back to Inventory" do
    get inventory_shopping_list_path(order_guide_id: @guide.id)
    assert_response :success
    assert in_content_links_to(inventory_path).any?,
      "expected an in-content link back to Inventory on the buy list"
    # The mobile chevron stays the primary mobile back affordance.
    assert_select "a.mobile-header-back[href=?]", inventory_path
  end

  test "the guide-chooser buy list also offers a desktop-visible way back to Inventory" do
    get inventory_shopping_list_path
    assert_response :success
    assert in_content_links_to(inventory_path).any?,
      "expected an in-content link back to Inventory on the guide-chooser buy list"
    assert_select "a.mobile-header-back[href=?]", inventory_path
  end

  test "the counts history offers a desktop-visible way back to Inventory" do
    get inventory_counts_path
    assert_response :success
    assert in_content_links_to(inventory_path).any?,
      "expected an in-content link back to Inventory on the counts history"
    assert_select "a.mobile-header-back[href=?]", inventory_path
  end

  test "the master inventory page offers a desktop-visible way back to Inventory" do
    get inventory_items_path
    assert_response :success
    assert in_content_links_to(inventory_path).any?,
      "expected an in-content link back to Inventory on the master inventory page"
    assert_select "a.mobile-header-back[href=?]", inventory_path
  end

  # The buy list is tri-origin. When reached from an order guide or a saved
  # count, the caller threads a return_to hint so back returns to that origin
  # instead of overshooting to Inventory. Default (no hint) stays Inventory.
  test "the buy list opened from an order guide returns to that guide" do
    get inventory_shopping_list_path(order_guide_id: @guide.id, return_to: "order_guide")
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", order_guide_path(@guide)
    assert_select "a.mobile-header-back[aria-label=?]", "Back to order guide"
    assert in_content_links_to(order_guide_path(@guide)).any?,
      "expected the desktop back button to point at the guide too"
    assert_select "a.mobile-header-back[href=?]", inventory_path, count: 0
  end

  test "the buy list opened from a saved count returns to that count" do
    count = InventoryCount.find_by!(order_guide: @guide)
    get inventory_shopping_list_path(order_guide_id: @guide.id, return_to: "count", count_id: count.id)
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", inventory_count_path(count)
    assert_select "a.mobile-header-back[aria-label=?]", "Back to count"
    assert_select "a.mobile-header-back[href=?]", inventory_path, count: 0
  end

  test "a stale or forged buy-list origin falls back to Inventory" do
    get inventory_shopping_list_path(order_guide_id: @guide.id, return_to: "count", count_id: 999_999)
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", inventory_path
    assert_select "a.mobile-header-back[aria-label=?]", "Back to Inventory"
  end
end
