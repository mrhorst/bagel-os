require "test_helper"

class ProductOrderGuideMembershipsTest < ActionDispatch::IntegrationTest
  setup do
    @supplier = Supplier.create!(name: "Primary Supplier")
    @guide = OrderGuide.create!(name: "Weekly")
  end

  test "product can be added to a guide as a counted operating row" do
    product = @supplier.products.create!(canonical_name: "Bacon", needs_review: false)

    get product_path(product)
    assert_response :success
    assert_select "h3", text: "Add to operating guide"

    post product_order_guide_memberships_path(product), params: {
      membership: {
        order_guide_id: @guide.id,
        section_name: "Freezer",
        item_name: "Bacon",
        count_unit: "case",
        tracking_mode: "counted",
        expected_usage_quantity: "2",
        buffer_quantity: "1"
      }
    }

    assert_redirected_to order_guide_path(@guide)
    item = product.inventory_items.first
    membership = item.order_guide_memberships.find_by!(order_guide: @guide)
    assert_equal "Bacon", item.name
    assert_equal "case", item.count_unit
    assert_equal "Freezer", membership.order_guide_section.name
    assert membership.counted?
    assert_equal BigDecimal("2"), membership.expected_usage_quantity
    assert_equal BigDecimal("1"), membership.buffer_quantity
  end

  test "product can be added to a guide as order only" do
    product = @supplier.products.create!(canonical_name: "Air Freshener", needs_review: false)

    post product_order_guide_memberships_path(product), params: {
      membership: {
        order_guide_id: @guide.id,
        section_name: "Cleaning shelf",
        item_name: "Air Freshener",
        tracking_mode: "order_only"
      }
    }

    assert_redirected_to order_guide_path(@guide)
    membership = product.inventory_items.first.order_guide_memberships.find_by!(order_guide: @guide)
    assert_equal "Cleaning shelf", membership.order_guide_section.name
    assert membership.order_only?
    assert_not membership.setup_needed?
  end
end
