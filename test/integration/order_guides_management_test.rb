require "test_helper"

class OrderGuidesManagementTest < ActionDispatch::IntegrationTest
  test "creates renames archives guides and assigns an inventory item primary guide" do
    section = InventorySection.create!(name: "Dairy", position: 1)
    item = InventoryItem.create!(name: "Cream Cheese", key: "cream-cheese", inventory_section: section)

    post order_guides_path, params: {
      order_guide: {
        name: "Every 2 weeks",
        notes: "Bulk items that do not need daily review."
      }
    }

    guide = OrderGuide.find_by!(name: "Every 2 weeks")
    assert_redirected_to order_guides_path
    assert guide.active?

    get inventory_items_path
    assert_response :success
    assert_select "select[name='order_guide_id'] option", text: "Every 2 weeks"

    patch inventory_item_primary_order_guide_path(item), params: { order_guide_id: guide.id }

    assert_redirected_to inventory_items_path
    assert_equal guide, item.reload.primary_order_guide

    patch order_guide_path(guide), params: { order_guide: { name: "Every other week" } }
    assert_redirected_to order_guides_path
    assert_equal "Every other week", guide.reload.name

    delete order_guide_path(guide)
    assert_redirected_to order_guides_path
    assert_not guide.reload.active?
    assert_nil item.reload.primary_order_guide
  end
end
