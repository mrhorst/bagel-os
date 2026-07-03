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

  test "a successful add from the gap list stays on the gap list, not the guide" do
    product = @supplier.products.create!(canonical_name: "Bacon", needs_review: false)

    # The gap-list form (order-guides index) threads return_to=gap_list so a
    # successful add keeps the user on the list to clear the next straggler,
    # instead of ejecting to the single guide on every add.
    post product_order_guide_memberships_path(product, return_to: "gap_list"), params: {
      membership: { order_guide_id: @guide.id, section_name: "Freezer", tracking_mode: "counted" }
    }

    assert_redirected_to order_guides_path(anchor: "guide-gaps")
    assert_equal "Bacon added to Weekly.", flash[:notice]
    assert product.reload.inventory_items.first.order_guide_memberships.exists?(order_guide: @guide)
  end

  test "a successful add without an origin hint lands on the guide (product-page caller)" do
    product = @supplier.products.create!(canonical_name: "Bacon", needs_review: false)

    post product_order_guide_memberships_path(product), params: {
      membership: { order_guide_id: @guide.id, section_name: "Freezer", tracking_mode: "counted" }
    }

    assert_redirected_to order_guide_path(@guide)
  end

  test "submitting without a guide gives a human message, not a raw lookup error" do
    product = @supplier.products.create!(canonical_name: "Olives", needs_review: false)

    post product_order_guide_memberships_path(product), params: {
      membership: { order_guide_id: "", section_name: "Dry", item_name: "Olives" }
    }

    assert_redirected_to product_path(product)
    assert_equal "Choose a guide to add this product to.", flash[:alert]
    assert_no_match(/Couldn't find/, flash[:alert].to_s)
    assert_empty product.inventory_items
  end

  test "the guide select is marked required so the browser blocks a guideless submit" do
    product = @supplier.products.create!(canonical_name: "Capers", needs_review: false)

    get product_path(product)
    assert_response :success
    assert_select "select[name='membership[order_guide_id]'][required]"
  end

  test "a failed add from the order-guides index keeps the user on the index, not a product page" do
    product = @supplier.products.create!(canonical_name: "Olives", needs_review: false)

    # The same "Add to guide" form lives on the order-guides index gap list
    # ("Receipt Products Not On Current Guides"). A recoverable mistake there
    # (forgetting to pick a guide) must not yank the user — mid-way through
    # clearing the gap list — onto a product page they never asked to see.
    post product_order_guide_memberships_path(product),
      params: { membership: { order_guide_id: "", section_name: "Dry" } },
      headers: { "HTTP_REFERER" => order_guides_url }

    assert_redirected_to order_guides_url
    assert_equal "Choose a guide to add this product to.", flash[:alert]
    assert_empty product.inventory_items
  end

  test "a failed add from the product page stays on the product page" do
    product = @supplier.products.create!(canonical_name: "Capers", needs_review: false)

    post product_order_guide_memberships_path(product),
      params: { membership: { order_guide_id: "", section_name: "Dry" } },
      headers: { "HTTP_REFERER" => product_url(product) }

    assert_redirected_to product_url(product)
    assert_equal "Choose a guide to add this product to.", flash[:alert]
    assert_empty product.inventory_items
  end
end
