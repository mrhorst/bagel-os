require "test_helper"

class ProductsFilterTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
    Purchasing::CsvImporter.new.import_file(Rails.root.join("test/fixtures/files/vendor_receipt_tuna_variations.csv"))
  end

  test "search matches raw variation names while showing canonical products" do
    get products_path(q: "tongol")

    assert_response :success
    assert_select "form[data-auto-submit-form]"
    assert_select "form[data-async-frame='products']"
    assert_select "[data-async-frame='products'] table"
    assert_select "input[data-filter-submit]"
    assert_select "td a", text: "Tongol Tuna"
    assert_select "td", text: "TUNA TONGOL CQ 66Z", count: 0
  end

  test "product chart modes render as client-switchable panels" do
    product = Product.find_by!(canonical_name: "Tongol Tuna")
    line = product.receipt_line_items.order(:id).first

    get product_path(product)

    assert_response :success
    assert_select "[data-chart-switcher][data-initial-chart-mode='standard_unit_price']"
    package_path = product_path(product, chart_mode: "package_price")
    assert_select "a[data-chart-mode='package_price'][href='#{package_path}']", text: "Presentation price"
    standard_unit_path = product_path(product, chart_mode: "standard_unit_price")
    assert_select "a[data-chart-mode='standard_unit_price'][href='#{standard_unit_path}']", text: "Comparable unit price"
    assert_select "[data-chart-panel='package_price'] svg.price-chart"
    assert_select "svg.price-chart .chart-date-label", text: "2026-05-13"
    assert_select "svg.price-chart .chart-axis-title[text-anchor='middle']", text: "Purchase date"
    assert_select "svg.price-chart circle[data-purchase-date='2026-05-13']"
    assert_select "svg.price-chart .chart-point-label[text-anchor]", minimum: 1
    assert_select "[data-chart-panel='standard_unit_price']"
    assert_select "[data-chart-summary='line_total']"
    assert_select "[data-chart-summary='quantity']"
    assert_select "table.purchase-history-table"
    assert_select "table.purchase-history-table th", text: "Inner price", count: 0
    assert_select "table.purchase-history-table details.purchase-details"
    assert_select "a[href='#{import_batch_path(line.import_batch, anchor: "receipt_line_item_#{line.id}")}']", text: "View"
    assert_select "a[href='#{edit_receipt_line_item_path(line)}']", text: "Edit"
  end

  test "product index paginates large product lists" do
    supplier = Supplier.primary
    category = ProductCategory.find_by!(name: "Dry goods")
    60.times do |index|
      supplier.products.create!(
        canonical_name: "Pagination Product #{index.to_s.rjust(2, '0')}",
        product_category: category,
        needs_review: false
      )
    end

    get products_path(per_page: 25)

    assert_response :success
    assert_select "[data-async-frame='products'] tbody tr", count: 25
    assert_select ".pagination"
    assert_select ".pagination a", text: "Next"
    assert_select ".pagination .active", text: "1"
    assert_select "[data-async-frame='products'] .muted", text: /Showing 25 of 62 products/

    get products_path(per_page: 25, page: 3)

    assert_response :success
    assert_select "[data-async-frame='products'] tbody tr", count: 12
    assert_select ".pagination .active", text: "3"
    assert_select "[data-async-frame='products'] .muted", text: /Page 3 of 3/
  end

  test "stylesheet preserves hidden option panels" do
    stylesheet = Rails.root.join("app/assets/stylesheets/application.css").read

    assert_match(/\[hidden\]\s*\{\s*display:\s*none\s*!important;\s*\}/m, stylesheet)
    assert_match(/\.grid\s*\{\s*align-items:\s*start;/m, stylesheet)
  end
end
