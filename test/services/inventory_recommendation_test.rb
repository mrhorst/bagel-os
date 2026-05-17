require "test_helper"

class InventoryRecommendationTest < ActiveSupport::TestCase
  setup do
    @section = InventorySection.create!(name: "Walk-in", position: 1)
  end

  test "marks uncounted active items separately from buy decisions" do
    item = create_item!(name: "Cream Cheese", current_par: 4, reorder_point: 2)

    row = recommendation.rows.find { |candidate| candidate.inventory_item == item }

    assert_nil row.quantity_on_hand
    assert_nil row.buy_quantity
    assert_equal "not_counted", row.status
  end

  test "recommends positive buy quantity when count is below par" do
    item = create_item!(name: "Eggs", current_par: 10, reorder_point: 3)
    count_item!(item, 6)

    row = recommendation.rows.find { |candidate| candidate.inventory_item == item }

    assert_equal BigDecimal("6"), row.quantity_on_hand
    assert_equal BigDecimal("4"), row.buy_quantity
    assert_equal "buy_now", row.status
  end

  test "marks near reorder when counted stock is at or below reorder point but not below par" do
    item = create_item!(name: "Butter", current_par: 3, reorder_point: 3)
    count_item!(item, 3)

    row = recommendation.rows.find { |candidate| candidate.inventory_item == item }

    assert_equal BigDecimal("0"), row.buy_quantity
    assert_equal "near_reorder", row.status
  end

  test "keeps inactive items out of the recommendation list" do
    active = create_item!(name: "Bacon", current_par: 2)
    inactive = create_item!(name: "Archived Sausage", current_par: 2, active: false)
    count_item!(active, 0)
    count_item!(inactive, 0)

    rows = recommendation.rows

    assert_includes rows.map(&:inventory_item), active
    assert_not_includes rows.map(&:inventory_item), inactive
    assert_equal [ active ], recommendation.buy_now.map(&:inventory_item)
  end

  private

  def recommendation
    Purchasing::InventoryRecommendation.new
  end

  def create_item!(name:, current_par:, reorder_point: nil, active: true)
    InventoryItem.create!(
      name: name,
      inventory_section: @section,
      current_par: current_par,
      reorder_point: reorder_point,
      active: active
    )
  end

  def count_item!(item, quantity)
    count = InventoryCount.create!(counted_at: Time.zone.local(2026, 5, 17), status: "completed")
    InventoryCountLine.create!(
      inventory_count: count,
      inventory_item: item,
      quantity_on_hand: quantity
    )
  end
end
