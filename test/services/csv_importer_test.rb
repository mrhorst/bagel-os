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
    eggs_line = ReceiptLineItem.find_by!(raw_name: "EGGS XLG LS GRD A 15DZ")
    assert_equal BigDecimal("1"), eggs_line.unit_quantity
    assert_equal BigDecimal("0"), eggs_line.case_quantity
    assert_equal "unit", eggs_line.purchase_kind
    assert_equal "unit", eggs_line.price_observation.purchase_kind
    assert_equal BigDecimal("15"), PriceObservation.find_by!(standard_unit: "dozen").standard_quantity
    assert_equal 1, NormalizationReview.where(issue_type: "coupon").count
  end

  test "keeps raw vendor receipt product specifications separate" do
    path = Rails.root.join("test/fixtures/files/vendor_receipt_tuna_variations.csv")

    Purchasing::CsvImporter.new.import_file(path)

    chunk_light = Product.find_by!(canonical_name: "Chunk Light Tuna")
    tongol = Product.find_by!(canonical_name: "Tongol Tuna")
    assert_equal 2, Product.count
    assert_nil chunk_light.supplier_sku
    assert_nil tongol.supplier_sku
    assert_not chunk_light.needs_review?
    assert_not tongol.needs_review?
    assert_equal [ "TUNA CHUNK LT CQ 66Z" ], chunk_light.product_aliases.pluck(:raw_name)
    assert_equal [ "TUNA TONGOL CQ 66Z" ], tongol.product_aliases.pluck(:raw_name)
    assert_includes chunk_light.notes, "Codex inference"
    assert_includes tongol.notes, "TUNA TONGOL CQ 66Z"
    assert_equal 1, chunk_light.price_observations.count
    assert_equal 1, tongol.price_observations.count
  end
end
