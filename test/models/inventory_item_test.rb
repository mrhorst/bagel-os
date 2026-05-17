require "test_helper"

class InventoryItemTest < ActiveSupport::TestCase
  test "merge guide frequency adopts guide type for manual items" do
    item = InventoryItem.create!(name: "Cream Cheese", guide_frequency: "manual")

    item.merge_guide_frequency!("weekly")

    assert_equal "weekly", item.reload.guide_frequency
  end

  test "merge guide frequency keeps the same guide type without writing" do
    item = InventoryItem.create!(name: "Eggs", guide_frequency: "daily")

    item.merge_guide_frequency!("daily")

    assert_equal "daily", item.reload.guide_frequency
  end

  test "merge guide frequency marks mixed daily and weekly guide coverage as both" do
    item = InventoryItem.create!(name: "Butter", guide_frequency: "daily")

    item.merge_guide_frequency!("weekly")

    assert_equal "both", item.reload.guide_frequency
  end
end
