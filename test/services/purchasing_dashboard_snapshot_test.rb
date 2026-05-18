require "test_helper"

class PurchasingDashboardSnapshotTest < ActiveSupport::TestCase
  setup do
    @service = Purchasing::PurchasingDashboardSnapshot.new
    @supplier = Supplier.create!(name: "Primary Supplier")
    @category = ProductCategory.create!(name: "Dairy", sort_order: 1)
    @import_batch = @supplier.import_batches.create!(
      source_filename: "dashboard-receipt.csv",
      file_checksum: "dashboard-receipt-checksum",
      imported_at: Time.zone.parse("2026-01-01 08:00:00"),
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @import_batch,
      receipt_number: "D-100",
      purchased_at: Time.zone.parse("2026-01-01 09:00:00"),
      total: 12
    )
  end

  test "builds the purchasing dashboard read model" do
    product = @supplier.products.create!(canonical_name: "Half and Half", product_category: @category, needs_review: true)
    line_item = @receipt.receipt_line_items.create!(
      supplier: @supplier,
      import_batch: @import_batch,
      product: product,
      line_number: 1,
      raw_name: "Half and Half raw",
      raw_sku: "HNH",
      raw_quantity: "1",
      quantity: 1,
      unit_quantity: 1,
      case_quantity: 0,
      package_price: 12,
      line_total: 12,
      confidence_score: 1,
      needs_review: false,
      row_checksum: "dashboard-row-1"
    )
    PriceObservation.create!(
      product: product,
      receipt_line_item: line_item,
      supplier: @supplier,
      observed_at: Time.zone.parse("2026-01-01 10:00:00"),
      package_price: 12,
      quantity: 1,
      line_total: 12,
      presentation_key: "quart",
      source_filename: @import_batch.source_filename,
      possible_price_spike: true
    )

    snapshot = @service.snapshot

    assert_equal BigDecimal("12"), snapshot.total_spend
    assert_equal 1, snapshot.receipt_count
    assert_equal 1, snapshot.product_count
    assert_equal [ [ "Dairy", BigDecimal("12") ] ], snapshot.category_spend
    assert_equal [ product ], snapshot.missing_standard.to_a
    assert_equal product, snapshot.spikes.first.product
  end
end
