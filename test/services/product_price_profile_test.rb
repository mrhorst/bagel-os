require "test_helper"

class ProductPriceProfileTest < ActiveSupport::TestCase
  setup do
    @service = Purchasing::ProductPriceProfile.new
    @supplier = Supplier.create!(name: "Primary Supplier")
    @category = ProductCategory.create!(name: "Dairy", sort_order: 1)
    @import_batch = @supplier.import_batches.create!(
      source_filename: "profile-receipt.csv",
      file_checksum: "profile-receipt-checksum",
      imported_at: Time.zone.parse("2026-01-01 08:00:00"),
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @import_batch,
      receipt_number: "P-100",
      purchased_at: Time.zone.parse("2026-01-01 09:00:00"),
      total: 0
    )
    @line_number = 0
  end

  test "builds one-product price profile with stats and chart summaries" do
    product = create_product("Cream Cheese")
    create_observation(
      product: product,
      package_price: 30,
      line_total: 30,
      standard_quantity: 10,
      standard_unit_price: 3,
      standard_unit: "lb",
      presentation_key: "case-10lb"
    )

    profile = @service.profile(product)

    assert_equal product, profile.product
    assert_equal BigDecimal("30"), profile.stats[:latest_price]
    assert_equal "standard_unit_price", profile.chart_mode
    assert_equal [ "case-10lb" ], profile.chart_summaries.fetch("package_price").fetch(:observations).map(&:presentation_key)
  end

  test "keeps presentation value insight local to the product profile read" do
    product = create_product("Large Eggs")
    create_observation(
      product: product,
      package_price: 27.39,
      line_total: 27.39,
      standard_quantity: 15,
      standard_unit_price: BigDecimal("1.826"),
      standard_unit: "dozen",
      presentation_key: "case-15dz",
      presentation_label: "15 dozen case"
    )
    create_observation(
      product: product,
      package_price: 9.99,
      line_total: 9.99,
      standard_quantity: 7.5,
      standard_unit_price: BigDecimal("1.332"),
      standard_unit: "dozen",
      presentation_key: "case-7-5dz",
      presentation_label: "7.5 dozen case"
    )

    insight = @service.chart_summaries(product.price_observations.chronological).fetch("package_price").fetch(:insight)

    assert_equal "presentation_value", insight.fetch(:kind)
    assert_equal "7.5 dozen case", insight.fetch(:best_label)
    assert_equal "15 dozen case", insight.fetch(:comparison_label)
  end

  private

  def create_product(name)
    @supplier.products.create!(canonical_name: name, product_category: @category)
  end

  def create_observation(
    product:,
    observed_at: Time.zone.parse("2026-01-01 10:00:00"),
    package_price: 10,
    line_total: 10,
    quantity: 1,
    standard_unit_price: nil,
    standard_unit: nil,
    standard_quantity: nil,
    presentation_key: "presentation",
    presentation_label: presentation_key
  )
    @line_number += 1
    line_item = @receipt.receipt_line_items.create!(
      supplier: @supplier,
      import_batch: @import_batch,
      product: product,
      line_number: @line_number,
      raw_name: "#{product.canonical_name} raw #{@line_number}",
      raw_sku: "SKU-#{@line_number}",
      raw_quantity: quantity.to_s,
      quantity: quantity,
      unit_quantity: quantity,
      case_quantity: 0,
      package_price: package_price,
      line_total: line_total,
      parsed_package_size: standard_quantity,
      parsed_unit_of_measure: standard_unit,
      confidence_score: 1,
      needs_review: false,
      row_checksum: "profile-row-#{@line_number}"
    )
    PriceObservation.create!(
      product: product,
      receipt_line_item: line_item,
      supplier: @supplier,
      observed_at: observed_at,
      package_price: package_price,
      quantity: quantity,
      line_total: line_total,
      standard_unit_price: standard_unit_price,
      standard_unit: standard_unit,
      standard_quantity: standard_quantity,
      presentation_key: presentation_key,
      presentation_label: presentation_label,
      source_filename: @import_batch.source_filename
    )
  end
end
