require "test_helper"

class CsvImporterTest < ActiveSupport::TestCase
  setup do
    load Rails.root.join("db/seeds.rb")
  end

  test "imports receipt lines, products, aliases, observations, and prevents duplicate imports" do
    path = Rails.root.join("test/fixtures/files/vendor_receipt_sample.csv")
    importer = Purchasing::CsvImporter.new

    first = importer.import_file(path)
    second = importer.import_file(path)

    assert_equal "imported", first[:batch].status
    assert second[:skipped]
    assert_equal 1, ImportBatch.where(source_filename: "vendor_receipt_sample.csv").count
    assert_equal 1, Receipt.count
    assert_equal 3, ReceiptLineItem.count
    assert_equal 2, Product.count
    assert_equal 2, ProductAlias.count
    assert_equal 2, PriceObservation.count
    assert_equal BigDecimal("15"), PriceObservation.find_by!(standard_unit: "dozen").standard_quantity
    assert_equal 1, NormalizationReview.where(issue_type: "coupon").count
  end

  test "groups raw vendor receipt variations under a simple canonical product" do
    path = Rails.root.join("test/fixtures/files/vendor_receipt_tuna_variations.csv")

    Purchasing::CsvImporter.new.import_file(path)

    product = Product.find_by!(canonical_name: "Tuna")
    assert_equal 1, Product.count
    assert_nil product.supplier_sku
    assert_not product.needs_review?
    assert_equal 2, product.product_aliases.count
    assert_equal [ "TUNA CHUNK LT CQ 66Z", "TUNA TONGOL CQ 66Z" ], product.product_aliases.order(:raw_name).pluck(:raw_name)
    assert_includes product.notes, "Codex inference"
    assert_includes product.notes, "TUNA TONGOL CQ 66Z"
    assert_equal 2, product.price_observations.count
  end
end
