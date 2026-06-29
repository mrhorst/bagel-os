require "test_helper"

# The home "Products" surface card must mirror the catalog's own notion of
# "records to clean up". The catalog hides products a manager unchecked
# "Visible in purchase catalog" on (active: false) — they are intentionally not
# part of the in-app browse/clean-up list — so the dashboard count must scope to
# active products too, the same way the sibling Order guides / Inventory review
# tiles already do. Counting hidden-but-unreviewed products inflates the KPI
# with work the destination page never surfaces (a phantom backlog).
class HomeDashboardProductsCardTest < ActionDispatch::IntegrationTest
  test "products card counts only active products needing review" do
    supplier = Supplier.create!(name: "Catalog Supplier A")

    Product.create!(canonical_name: "Visible needs review", supplier: supplier, active: true, needs_review: true)
    # Hidden from the catalog — must NOT inflate the dashboard count, because the
    # products page it links to won't surface it by default.
    Product.create!(canonical_name: "Hidden needs review", supplier: supplier, active: false, needs_review: true)

    get root_path

    assert_response :success
    assert_products_summary "1 records to clean up"
    assert_select "a.home-surface-card-active[href=?]", products_path
  end

  test "products card reads clean when only hidden products need review" do
    supplier = Supplier.create!(name: "Catalog Supplier B")

    Product.create!(canonical_name: "Hidden needs review", supplier: supplier, active: false, needs_review: true)
    Product.create!(canonical_name: "Reviewed and visible", supplier: supplier, active: true, needs_review: false)

    get root_path

    assert_response :success
    assert_products_summary "Records look complete"
    assert_select "a.home-surface-card-active[href=?]", products_path, count: 0
  end

  private

  def assert_products_summary(text)
    assert_select "a[href=?] .home-surface-card-summary", products_path, text: text
  end
end
