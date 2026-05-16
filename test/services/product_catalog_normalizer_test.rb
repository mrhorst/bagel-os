require "test_helper"

class ProductCatalogNormalizerTest < ActiveSupport::TestCase
  setup do
    load Rails.root.join("db/seeds.rb")
    @supplier = Supplier.primary
    @batch = @supplier.import_batches.create!(
      source_filename: "normalizer-test.csv",
      source_path: "normalizer-test.csv",
      file_checksum: "normalizer-test",
      imported_at: Time.zone.local(2026, 5, 16),
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @batch,
      receipt_number: "NORMALIZER-1",
      purchased_at: Time.zone.local(2026, 5, 16)
    )
  end

  test "reassigns split product specs and removes stale aliases from the broad product" do
    mayo = @supplier.products.create!(
      canonical_name: "Mayonnaise",
      product_category: ProductCategory.find_by!(name: "Condiments"),
      needs_review: false
    )
    mayo.product_aliases.create!(raw_name: "MAYO REAL CQ GAL", raw_sku: "MAYO-CQ", approved: true)
    mayo.product_aliases.create!(raw_name: "PC MAYO PCH CQ 200CT", raw_sku: "MAYO-PC", approved: true)
    gallon_line = create_line!(product: mayo, raw_name: "MAYO REAL CQ GAL", raw_sku: "MAYO-CQ", line_number: 1)
    packet_line = create_line!(product: mayo, raw_name: "PC MAYO PCH CQ 200CT", raw_sku: "MAYO-PC", line_number: 2)

    stats = Purchasing::ProductCatalogNormalizer.new(supplier: @supplier).normalize_all!

    assert_equal mayo, gallon_line.reload.product
    assert_equal "Mayonnaise Packets", packet_line.reload.product.canonical_name
    assert_equal [ "MAYO REAL CQ GAL" ], mayo.product_aliases.reload.pluck(:raw_name)
    assert_equal 1, stats.fetch(:stale_aliases_removed)
  end

  private

  def create_line!(product:, raw_name:, raw_sku:, line_number:)
    @receipt.receipt_line_items.create!(
      supplier: @supplier,
      import_batch: @batch,
      product: product,
      line_number: line_number,
      raw_name: raw_name,
      raw_sku: raw_sku,
      raw_quantity: "1",
      unit_quantity: 1,
      case_quantity: 0,
      quantity: 1,
      raw_unit: "unit",
      line_total: 10,
      package_price: 10,
      row_checksum: "line-#{line_number}",
      needs_review: false
    )
  end
end
