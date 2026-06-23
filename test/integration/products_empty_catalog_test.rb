require "test_helper"

# A brand-new install (or any tenant before its first receipt import) lands on
# Products with an empty catalog. The empty state must not be a dead end: it
# tells the user to import receipts, so it has to offer a way to do it.
class ProductsEmptyCatalogTest < ActionDispatch::IntegrationTest
  test "an empty catalog offers an import action so the user is not dead-ended" do
    assert_equal 0, Product.count, "no fixtures should seed products for this test"

    get products_path

    assert_response :success
    assert_select "[data-async-frame='products'] tbody tr", count: 0
    assert_select ".dashboard-empty-state", text: /No products to show/
    assert_select ".dashboard-empty-state a[href='#{new_import_batch_path}']", text: "Import receipts"
  end

  test "an empty catalog hides the import action from a user without import access" do
    member = users(:two)
    member.grant_module("products")
    sign_in_as(member)

    get products_path

    assert_response :success
    assert_select ".dashboard-empty-state", text: /No products to show/
    assert_select ".dashboard-empty-state a[href='#{new_import_batch_path}']", count: 0
  end
end
