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
    assert_select "td a", text: "Tuna"
    assert_select "td", text: "TUNA TONGOL CQ 66Z", count: 0
  end

  test "product chart modes render as client-switchable panels" do
    product = Product.find_by!(canonical_name: "Tuna")

    get product_path(product)

    assert_response :success
    assert_select "[data-chart-switcher][data-initial-chart-mode='standard_unit_price']"
    package_path = product_path(product, chart_mode: "package_price")
    assert_select "a[data-chart-mode='package_price'][href='#{package_path}']", text: "Presentation price"
    standard_unit_path = product_path(product, chart_mode: "standard_unit_price")
    assert_select "a[data-chart-mode='standard_unit_price'][href='#{standard_unit_path}']", text: "Comparable unit price"
    assert_select "[data-chart-panel='package_price'] svg.price-chart"
    assert_select "[data-chart-panel='standard_unit_price']"
    assert_select "[data-chart-summary='line_total']"
    assert_select "[data-chart-summary='quantity']"
  end

  test "stylesheet preserves hidden option panels" do
    stylesheet = Rails.root.join("app/assets/stylesheets/application.css").read

    assert_match(/\[hidden\]\s*\{\s*display:\s*none\s*!important;\s*\}/m, stylesheet)
  end
end
