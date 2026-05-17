require "test_helper"

class InventoryCountsTest < ActionDispatch::IntegrationTest
  setup do
    @section = InventorySection.create!(name: "Walk-in", position: 1)
    @cream_cheese = InventoryItem.create!(name: "Cream Cheese", inventory_section: @section, count_unit: "tub")
    @eggs = InventoryItem.create!(name: "Eggs", inventory_section: @section, count_unit: "case")
  end

  test "creates a manual inventory count from submitted rows and skips blanks" do
    post inventory_counts_path, params: {
      notes: "Sunday morning count",
      counts: {
        @cream_cheese.id => "4.5",
        @eggs.id => ""
      }
    }

    assert_redirected_to inventory_counts_path
    count = InventoryCount.last
    assert_equal "Sunday morning count", count.notes
    assert_equal 1, count.inventory_count_lines.count
    line = count.inventory_count_lines.first
    assert_equal @cream_cheese, line.inventory_item
    assert_equal BigDecimal("4.5"), line.quantity_on_hand
    assert_equal "tub", line.unit
  end

  test "rejects empty inventory count submissions" do
    post inventory_counts_path, params: { counts: { @cream_cheese.id => "" } }

    assert_redirected_to new_inventory_count_path
    assert_equal 0, InventoryCount.count
  end
end
