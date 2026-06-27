require "test_helper"

# A brand-new install (or any tenant before its first order guide) lands on the
# Stock screens with no guides. Those empty states tell the user to "create an
# order guide" — so, like the sibling New Count and Product screens already do,
# they must offer a way to actually create one instead of dead-ending.
class InventoryEmptyGuidesTest < ActionDispatch::IntegrationTest
  setup do
    assert_equal 0, OrderGuide.count, "no fixtures should seed order guides for this test"
  end

  test "the inventory landing empty state offers a create-order-guide action" do
    get inventory_path

    assert_response :success
    assert_select ".empty-state", text: /Create an order guide before starting counts or buy lists\./
    assert_select "a.button.primary[href=?]", order_guides_path, text: "Create order guide"
  end

  test "the shopping list empty state offers a create-order-guide action" do
    get inventory_shopping_list_path

    assert_response :success
    assert_select ".empty-state", text: /Create an order guide before generating a shopping list\./
    assert_select "a.button.primary[href=?]", order_guides_path, text: "Create order guide"
  end
end
