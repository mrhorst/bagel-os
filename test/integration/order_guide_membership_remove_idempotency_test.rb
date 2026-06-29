require "test_helper"

# Removing an order-guide row that has already been removed (a double-tapped
# "×", a stale tab, or two staff working the same guide) must land the user
# back on the guide with reassuring feedback — not a raw 404 dead-end. The
# sibling create/update actions in this controller already rescue a missing
# record into a place-preserving redirect; destroy must do the same.
class OrderGuideMembershipRemoveIdempotencyTest < ActionDispatch::IntegrationTest
  setup do
    @section = InventorySection.create!(name: "Dairy", position: 1)
    @item = InventoryItem.create!(name: "Cream Cheese", key: "cream-cheese", inventory_section: @section)
    @guide = OrderGuide.create!(name: "Weekly")
    @membership = @item.add_to_order_guide!(
      @guide,
      order_guide_section: @guide.section_named!("Dairy"),
      tracking_mode: "counted"
    )
  end

  test "removing a row twice lands back on the guide, not a 404 dead-end" do
    delete order_guide_membership_path(@guide, @membership)
    assert_redirected_to order_guide_path(@guide)
    assert_not @membership.reload.active?

    # Second removal — the row is already gone. Must not 404.
    delete order_guide_membership_path(@guide, @membership)
    assert_redirected_to order_guide_path(@guide)
    assert flash[:notice].present? || flash[:alert].present?,
      "expected reassuring feedback after re-removing an already-removed row"
  end
end
