require "test_helper"

# The product workspace (products/show) is the catalog's detail page: it is
# reached from the Products index and sends its mobile top-left chevron back to
# the catalog. But the detail page exposed no in-content *desktop* control back
# to the catalog — the page header carried only an "Edit product" action, and the
# back chevron lives in the mobile-only header (.mobile-screen-header,
# display:none on desktop). On a wide screen the only way back to the catalog was
# the global sidebar's "Stock" item, which points at the module hub (not the
# Products catalog) and renders as the *active* entry on this page — so a user had
# to click an already-active nav item that overshoots their destination. Every
# sibling detail page (Inventory → "Back to Inventory", Imports → "All imports",
# Order Guides → "All guides", Follow-ups → "Follow-ups") mirrors its mobile
# chevron with a desktop-visible control; these assert the product workspace now
# does too, without disturbing the mobile chevron.
class ProductsBackNavigationTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
    Purchasing::CsvImporter.new.import_file(Rails.root.join("test/fixtures/files/vendor_receipt_tuna_variations.csv"))
    @product = Product.find_by!(canonical_name: "Tongol Tuna")
  end

  # Strip the chrome hidden on desktop (the mobile screen header) and the
  # always-present global sidebar, so what's left is the in-content page body a
  # wide-screen user navigates by.
  def in_content_links_to(path)
    doc = Nokogiri::HTML(response.body)
    doc.css(".mobile-screen-header, .app-sidebar").remove
    doc.css("a").select { |a| a["href"] == path }
  end

  test "the product workspace offers a desktop-visible way back to the catalog" do
    get product_path(@product)
    assert_response :success
    assert in_content_links_to(products_path).any?,
      "expected an in-content link back to the Products catalog on the product workspace"
    # The mobile chevron stays the primary mobile back affordance.
    assert_select "a.mobile-header-back[href=?]", products_path
  end
end
