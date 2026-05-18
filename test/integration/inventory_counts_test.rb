require "test_helper"

class InventoryCountsTest < ActionDispatch::IntegrationTest
  setup do
    @guide = OrderGuide.create!(name: "Weekly")
    @walk_in = @guide.section_named!("Walk-in")
    @freezer = @guide.section_named!("Freezer")
    @cream_cheese = InventoryItem.create!(name: "Cream Cheese", count_unit: "tub")
    @eggs = InventoryItem.create!(name: "Eggs", count_unit: "case")
    @air_freshener = InventoryItem.create!(name: "Air Freshener", count_unit: "each")
    @cream_membership = @cream_cheese.add_to_order_guide!(
      @guide,
      order_guide_section: @walk_in,
      tracking_mode: "counted",
      expected_usage_quantity: 4,
      buffer_quantity: 1
    )
    @egg_membership = @eggs.add_to_order_guide!(
      @guide,
      order_guide_section: @freezer,
      tracking_mode: "counted",
      expected_usage_quantity: 2,
      buffer_quantity: 1
    )
    @air_freshener.add_to_order_guide!(@guide, order_guide_section: @walk_in, tracking_mode: "order_only")
  end

  test "new count page groups countable rows by guide section and excludes order only rows" do
    get new_inventory_count_path(order_guide_id: @guide.id)

    assert_response :success
    assert_select "h1", text: "Count Weekly"
    assert_select "h2", text: "Walk-in"
    assert_select "h2", text: "Freezer"
    assert_match "Cream Cheese", response.body
    assert_match "Eggs", response.body
    assert_no_match "Air Freshener", response.body
  end

  test "creates a guide inventory count from submitted rows and skips blanks" do
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      notes: "Sunday morning count",
      counts: {
        @cream_membership.id => "4.5",
        @egg_membership.id => ""
      }
    }

    assert_redirected_to inventory_shopping_list_path(order_guide_id: @guide.id)
    count = InventoryCount.last
    assert_equal @guide, count.order_guide
    assert_equal "Sunday morning count", count.notes
    assert_equal 1, count.inventory_count_lines.count
    line = count.inventory_count_lines.first
    assert_equal @cream_cheese, line.inventory_item
    assert_equal @cream_membership, line.order_guide_membership
    assert_equal BigDecimal("4.5"), line.quantity_on_hand
    assert_equal "tub", line.unit
  end

  test "rejects empty guide inventory count submissions" do
    post inventory_counts_path, params: { order_guide_id: @guide.id, counts: { @cream_membership.id => "" } }

    assert_redirected_to new_inventory_count_path(order_guide_id: @guide.id)
    assert_equal 0, InventoryCount.count
  end

  test "guide shopping list shows buy now setup not counted and order only sections" do
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      counts: {
        @cream_membership.id => "2"
      }
    }

    unconfigured_item = InventoryItem.create!(name: "Napkins", count_unit: "case")
    unconfigured_item.add_to_order_guide!(@guide, order_guide_section: @walk_in, tracking_mode: "counted")

    get inventory_shopping_list_path(order_guide_id: @guide.id)

    assert_response :success
    assert_select "h1", text: "Weekly Buy List"
    assert_select "h2", text: "Buy Now"
    assert_match "Cream Cheese", response.body
    assert_match "Napkins", response.body
    assert_match "Eggs", response.body
    assert_match "Air Freshener", response.body
    assert_select ".badge", text: "Buy now"
  end
end
