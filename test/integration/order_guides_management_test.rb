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

    get order_guides_path
    assert_response :success
    assert_select "a", text: "Download CSV example"
    assert_no_match "Import current PDFs", response.body
    assert_select "h2", text: "Items By Guide"
    assert_match "Cream Cheese", response.body

    get order_guide_path(guide)
    assert_response :success
    assert_select "h1", text: "Every 2 weeks"
    assert_select "h2", text: "Add Existing Operating Item"
    assert_match "Cream Cheese", response.body

    patch order_guide_path(guide), params: { order_guide: { name: "Every other week" } }
    assert_redirected_to order_guides_path
    assert_equal "Every other week", guide.reload.name

    delete order_guide_path(guide)
    assert_redirected_to order_guides_path
    assert_not guide.reload.active?
    assert_nil item.reload.primary_order_guide
  end

  test "downloads csv example for order guide import shape" do
    get csv_example_order_guides_path

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "guide_name,item_name,section,category,count_unit,pack_size,primary_guide,position,notes"
    assert_includes response.body, "Daily,Eggs,Walk-in cooler"
  end

  test "adds removes and re-adds existing inventory items from a guide" do
    guide = OrderGuide.create!(name: "Daily")
    section = InventorySection.create!(name: "Walk-in cooler", position: 1)
    item = InventoryItem.create!(name: "Eggs", key: "eggs", inventory_section: section)

    get order_guide_path(guide)
    assert_response :success
    assert_select "select[name='membership[inventory_item_id]'] option", text: "Eggs"

    post order_guide_memberships_path(guide), params: {
      membership: {
        inventory_item_id: item.id,
        section_name: "Walk-in cooler",
        tracking_mode: "counted",
        expected_usage_quantity: "6",
        buffer_quantity: "2"
      }
    }

    assert_redirected_to order_guide_path(guide)
    membership = guide.order_guide_memberships.find_by!(inventory_item: item)
    assert membership.active?
    assert_equal "Walk-in cooler", membership.order_guide_section.name
    assert_equal BigDecimal("8"), membership.target_after_order

    get order_guide_path(guide)
    assert_response :success
    assert_match "Eggs", response.body
    assert_select "form[action='#{order_guide_membership_path(guide, membership)}']"

    delete order_guide_membership_path(guide, membership)

    assert_redirected_to order_guide_path(guide)
    assert_not membership.reload.active?

    get order_guide_path(guide)
    assert_response :success
    assert_no_match(/<strong>Eggs<\/strong>/, response.body)
    assert_select "select[name='membership[inventory_item_id]'] option", text: "Eggs"

    post order_guide_memberships_path(guide), params: {
      membership: {
        inventory_item_id: item.id,
        section_name: "Walk-in cooler",
        tracking_mode: "order_only"
      }
    }

    assert_redirected_to order_guide_path(guide)
    assert membership.reload.active?
    assert membership.order_only?
    assert_equal 1, guide.order_guide_memberships.where(inventory_item: item).count
  end

  test "updates guide membership setup fields inline" do
    guide = OrderGuide.create!(name: "Weekly")
    item = InventoryItem.create!(name: "Bacon", key: "bacon")
    membership = item.add_to_order_guide!(guide, tracking_mode: "counted")

    patch order_guide_membership_path(guide, membership), params: {
      membership: {
        section_name: "Freezer",
        tracking_mode: "counted",
        expected_usage_quantity: "2",
        buffer_quantity: "1"
      }
    }

    assert_redirected_to order_guide_path(guide)
    assert_equal "Freezer", membership.reload.order_guide_section.name
    assert_equal BigDecimal("3"), membership.target_after_order
  end

  test "removing primary item from guide leaves item without primary guide" do
    guide = OrderGuide.create!(name: "Weekly")
    item = InventoryItem.create!(name: "Coffee beans", key: "coffee-beans")
    membership = item.add_to_order_guide!(guide, primary: true)

    delete order_guide_membership_path(guide, membership)

    assert_redirected_to order_guide_path(guide)
    assert_not membership.reload.active?
    assert_nil item.reload.primary_order_guide
  end

  test "changing primary guide from master inventory reactivates membership" do
    guide = OrderGuide.create!(name: "Every 2 weeks")
    item = InventoryItem.create!(name: "Napkins", key: "napkins")
    membership = item.add_to_order_guide!(guide, primary: true)
    membership.deactivate!

    patch inventory_item_primary_order_guide_path(item), params: { order_guide_id: guide.id }

    assert_redirected_to inventory_items_path
    assert membership.reload.active?
    assert membership.primary_guide?
    assert_equal guide, item.reload.primary_order_guide
  end
end
