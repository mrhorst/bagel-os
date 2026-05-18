require "test_helper"

class OrderGuideRecommendationTest < ActiveSupport::TestCase
  setup do
    @guide = OrderGuide.create!(name: "Weekly")
    @section = @guide.section_named!("Freezer")
  end

  test "uses expected usage plus buffer as target after order" do
    item = InventoryItem.create!(name: "Bacon", key: "bacon", count_unit: "case")
    membership = item.add_to_order_guide!(
      @guide,
      order_guide_section: @section,
      tracking_mode: "counted",
      expected_usage_quantity: 2,
      buffer_quantity: 1
    )
    count_membership!(membership, 1)

    row = recommendation.rows.find { |candidate| candidate.membership == membership }

    assert_equal BigDecimal("1"), row.quantity_on_hand
    assert_equal BigDecimal("3"), row.target_after_order
    assert_equal BigDecimal("2"), row.buy_quantity
    assert_equal "buy_now", row.status
  end

  test "marks counted rows missing usage or buffer as setup needed" do
    item = InventoryItem.create!(name: "Cream Cheese", key: "cream-cheese")
    membership = item.add_to_order_guide!(@guide, order_guide_section: @section, tracking_mode: "counted")

    row = recommendation.rows.find { |candidate| candidate.membership == membership }

    assert_nil row.buy_quantity
    assert_equal "setup_needed", row.status
  end

  test "marks ready counted rows without counts as not counted" do
    item = InventoryItem.create!(name: "Eggs", key: "eggs")
    membership = item.add_to_order_guide!(
      @guide,
      order_guide_section: @section,
      tracking_mode: "counted",
      expected_usage_quantity: 4,
      buffer_quantity: 1
    )

    row = recommendation.rows.find { |candidate| candidate.membership == membership }

    assert_nil row.quantity_on_hand
    assert_equal "not_counted", row.status
  end

  test "keeps order only rows out of count math" do
    item = InventoryItem.create!(name: "Air Freshener", key: "air-freshener")
    membership = item.add_to_order_guide!(@guide, order_guide_section: @section, tracking_mode: "order_only")

    row = recommendation.rows.find { |candidate| candidate.membership == membership }

    assert_nil row.quantity_on_hand
    assert_nil row.buy_quantity
    assert_equal "order_only", row.status
    assert_equal [ membership ], recommendation.order_only.map(&:membership)
  end

  private

  def recommendation
    Purchasing::OrderGuideRecommendation.new(@guide)
  end

  def count_membership!(membership, quantity)
    count = InventoryCount.create!(
      order_guide: @guide,
      counted_at: Time.zone.local(2026, 5, 18),
      status: "completed"
    )
    InventoryCountLine.create!(
      inventory_count: count,
      order_guide_membership: membership,
      inventory_item: membership.inventory_item,
      quantity_on_hand: quantity
    )
  end
end
