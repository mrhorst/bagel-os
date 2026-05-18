require "test_helper"

class OrderGuideMembershipTest < ActiveSupport::TestCase
  test "inventory item can belong to multiple guides with one active primary guide" do
    item = InventoryItem.create!(name: "Half and Half", key: "half-and-half")
    daily = OrderGuide.create!(name: "Daily")
    every_two_weeks = OrderGuide.create!(name: "Every 2 weeks")

    item.add_to_order_guide!(daily, primary: true, position: 1)
    item.add_to_order_guide!(every_two_weeks, primary: true, position: 2)

    assert_equal [ "Daily", "Every 2 weeks" ], item.order_guides.order(:name).pluck(:name)
    assert_equal every_two_weeks, item.reload.primary_order_guide
    assert_not item.order_guide_memberships.find_by!(order_guide: daily).primary_guide?
    assert item.order_guide_memberships.find_by!(order_guide: every_two_weeks).primary_guide?
  end

  test "assigning blank primary guide keeps memberships but clears primary flag" do
    item = InventoryItem.create!(name: "Napkins", key: "napkins")
    guide = OrderGuide.create!(name: "Cleaning Supplies")

    item.assign_primary_order_guide!(guide)
    item.assign_primary_order_guide!(nil)

    assert_nil item.reload.primary_order_guide
    assert_equal [ guide ], item.order_guides.to_a
    assert item.order_guide_memberships.find_by!(order_guide: guide).active?
  end

  test "archiving a guide deactivates memberships without deleting traceability" do
    item = InventoryItem.create!(name: "Paper towels", key: "paper-towels")
    guide = OrderGuide.create!(name: "Monthly")
    membership = item.add_to_order_guide!(guide, primary: true)

    guide.archive!

    assert_not guide.reload.active?
    assert_not membership.reload.active?
    assert_nil item.reload.primary_order_guide
  end

  test "reactivating an inactive membership does not create a duplicate" do
    item = InventoryItem.create!(name: "Trash bags", key: "trash-bags")
    guide = OrderGuide.create!(name: "Cleaning Supplies")
    membership = item.add_to_order_guide!(guide, primary: true)
    membership.deactivate!

    reactivated = item.add_to_order_guide!(guide)

    assert_equal membership, reactivated
    assert reactivated.active?
    assert_not reactivated.primary_guide?
    assert_equal 1, item.order_guide_memberships.where(order_guide: guide).count
  end

  test "removing primary membership clears the item primary guide" do
    item = InventoryItem.create!(name: "Whole milk", key: "whole-milk")
    guide = OrderGuide.create!(name: "Daily")
    membership = item.add_to_order_guide!(guide, primary: true)

    membership.deactivate!

    assert_not membership.reload.active?
    assert_not membership.primary_guide?
    assert_nil item.reload.primary_order_guide
  end

  test "removing non-primary membership leaves primary unchanged" do
    item = InventoryItem.create!(name: "Coffee beans", key: "coffee-beans")
    weekly = OrderGuide.create!(name: "Weekly")
    prep = OrderGuide.create!(name: "Weekend Prep")
    item.add_to_order_guide!(weekly, primary: true)
    secondary_membership = item.add_to_order_guide!(prep)

    secondary_membership.deactivate!

    assert_not secondary_membership.reload.active?
    assert_equal weekly, item.reload.primary_order_guide
  end
end
