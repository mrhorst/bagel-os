require "test_helper"

class OrderGuideEmptyInventoryTest < ActionDispatch::IntegrationTest
  # On a fresh install no inventory items exist yet. Viewing a brand-new order
  # guide must not claim every item is "already on this guide" — there are none.
  test "active guide with no inventory items does not claim every item is already on the guide" do
    sign_in_as(users(:one))

    OrderGuideMembership.delete_all
    InventoryItem.delete_all
    guide = OrderGuide.create!(name: "Empty Guide")

    get order_guide_path(guide)
    assert_response :success

    assert_no_match(/Every active inventory item is already on this guide/, response.body,
      "Shows a false 'all items already added' hint when zero inventory items exist")
    assert_match(/No inventory items/, response.body,
      "Should explain that no inventory items exist yet")
  end

  # When items exist but all are already on the guide, the original hint is correct.
  test "active guide with all items already assigned keeps the all-assigned hint" do
    sign_in_as(users(:one))

    guide = OrderGuide.create!(name: "Full Guide")
    item = InventoryItem.create!(name: "Probe Item", active: true)
    guide.order_guide_memberships.create!(inventory_item: item, tracking_mode: "counted", position: 1)

    get order_guide_path(guide)
    assert_response :success
    assert_match(/Every active inventory item is already on this guide/, response.body)
  end
end
