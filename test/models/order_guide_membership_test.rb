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
end
