require "test_helper"

class PriceIntelligenceTest < ActiveSupport::TestCase
  setup do
    @service = Purchasing::PriceIntelligence.new
    @supplier = Supplier.create!(name: "Primary Supplier")
    @category = ProductCategory.create!(name: "Dairy", sort_order: 1)
    @import_batch = @supplier.import_batches.create!(
      source_filename: "demo-receipt.csv",
      file_checksum: "demo-receipt-checksum",
      imported_at: Time.zone.parse("2026-01-01 08:00:00"),
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @import_batch,
      receipt_number: "R-100",
      purchased_at: Time.zone.parse("2026-01-01 09:00:00"),
      total: 0
    )
    @line_number = 0
  end

  test "uses latest reliable comparable unit price while keeping latest package price" do
    product = create_product("Butter")
    create_observation(
      product: product,
      observed_at: Time.zone.parse("2026-01-01 10:00:00"),
      package_price: 24,
      line_total: 24,
      standard_unit_price: 3,
      standard_unit: "lb",
      presentation_key: "case-8lb"
    )
    create_observation(
      product: product,
      observed_at: Time.zone.parse("2026-02-01 10:00:00"),
      package_price: 30,
      line_total: 30,
      standard_unit_price: nil,
      standard_unit: nil,
      presentation_key: "unknown-pack"
    )

    stats = @service.price_stats(product)

    assert_equal BigDecimal("30"), stats[:latest_price]
    assert_equal BigDecimal("3"), stats[:latest_standard_unit_price]
  end

  test "summarizes package prices by inner package when case pack facts are reviewed" do
    product = create_product("American Cheese Yellow")
    create_observation(
      product: product,
      observed_at: Time.zone.parse("2026-03-28 10:00:00"),
      package_price: 13.65,
      line_total: 13.65,
      quantity: 1,
      standard_quantity: 5,
      standard_unit_price: 2.73,
      standard_unit: "lb",
      presentation_key: "unit-5lb"
    )
    create_observation(
      product: product,
      observed_at: Time.zone.parse("2026-04-03 10:00:00"),
      package_price: 47.78,
      line_total: 47.78,
      quantity: 1,
      unit_quantity: 0,
      case_quantity: 1,
      purchase_kind: "case",
      inner_quantity: 4,
      inner_unit_price: 11.945,
      inner_unit_label: "pack",
      standard_quantity: 20,
      standard_unit_price: 2.389,
      standard_unit: "lb",
      presentation_key: "case-4x5lb"
    )
    create_observation(
      product: product,
      observed_at: Time.zone.parse("2026-05-06 10:00:00"),
      package_price: 12.74,
      line_total: 12.74,
      quantity: 1,
      standard_quantity: 5,
      standard_unit_price: 2.548,
      standard_unit: "lb",
      presentation_key: "unit-5lb"
    )

    stats = @service.price_stats(product)

    assert_equal BigDecimal("12.74"), stats[:latest_price]
    assert_equal BigDecimal("12.3617"), stats[:average_price]
    assert_equal BigDecimal("11.945"), stats[:lowest_price]
    assert_equal BigDecimal("13.65"), stats[:highest_price]
    assert_equal BigDecimal("2.4723"), stats[:average_standard_unit_price]
  end

  test "defaults chart mode to comparable unit when reliable and respects valid requests" do
    product = create_product("Cream Cheese")
    create_observation(
      product: product,
      standard_unit_price: 2.50,
      standard_unit: "lb",
      presentation_key: "tub-30lb"
    )
    profile = @service.product_profile(product)
    requested_profile = @service.product_profile(product, requested_chart_mode: "package_price")
    invalid_profile = @service.product_profile(product, requested_chart_mode: "not-a-mode")

    assert_equal "standard_unit_price", profile.chart_mode
    assert_equal "package_price", requested_profile.chart_mode
    assert_equal "standard_unit_price", invalid_profile.chart_mode
  end

  test "defaults chart mode to inner unit price when no comparable unit exists" do
    product = create_product("American Cheese Yellow")
    create_observation(
      product: product,
      standard_unit_price: nil,
      inner_unit_price: 20,
      inner_unit_label: "pack",
      presentation_key: "case-cheese"
    )

    profile = @service.product_profile(product)

    assert_equal "inner_unit_price", profile.chart_mode
    assert_equal BigDecimal("20"), profile.chart_summaries.fetch("inner_unit_price").fetch(:observations).first.inner_unit_price
  end


  test "separates presentation series while comparing shared standard-unit series" do
    product = create_product("Bananas")
    create_observation(
      product: product,
      observed_at: Time.zone.parse("2026-01-01 10:00:00"),
      package_price: 25,
      line_total: 25,
      standard_unit_price: 1,
      standard_unit: "lb",
      presentation_key: "case-25lb"
    )
    create_observation(
      product: product,
      observed_at: Time.zone.parse("2026-01-15 10:00:00"),
      package_price: 3,
      line_total: 3,
      standard_unit_price: 1.5,
      standard_unit: "lb",
      presentation_key: "bag-2lb"
    )

    summaries = @service.chart_summaries(product.price_observations.chronological)

    assert_nil summaries.fetch("package_price").fetch(:recent_change)
    assert_equal 50.0, summaries.fetch("standard_unit_price").fetch(:recent_change)
  end

  test "calculates chart change windows from the first observation inside each window" do
    product = create_product("Eggs")
    create_observation(
      product: product,
      observed_at: Time.zone.parse("2026-01-01 10:00:00"),
      standard_unit_price: 1,
      standard_unit: "dz",
      presentation_key: "case-15dz"
    )
    create_observation(
      product: product,
      observed_at: Time.zone.parse("2026-03-01 10:00:00"),
      standard_unit_price: 2,
      standard_unit: "dz",
      presentation_key: "case-15dz"
    )
    create_observation(
      product: product,
      observed_at: Time.zone.parse("2026-03-20 10:00:00"),
      standard_unit_price: 3,
      standard_unit: "dz",
      presentation_key: "case-15dz"
    )

    summary = @service.chart_summaries(product.price_observations.chronological).fetch("standard_unit_price")

    assert_equal 200.0, summary.fetch(:recent_change)
    assert_equal 50.0, summary.fetch(:change_30_days)
    assert_equal 50.0, summary.fetch(:change_60_days)
    assert_equal 200.0, summary.fetch(:change_90_days)
  end

  test "filters product index by raw aliases and sorts by spend" do
    low_spend = create_product("Blueberries")
    high_spend = create_product("Strawberries")
    high_spend.product_aliases.create!(raw_name: "STRAW RAW 8/1LB", raw_sku: "STRAW-RAW", approved: true)
    create_observation(product: low_spend, line_total: 10, package_price: 10, presentation_key: "flat")
    create_observation(product: high_spend, line_total: 40, package_price: 40, presentation_key: "flat")

    search_results = @service.product_index(ActionController::Parameters.new(q: "straw raw")).to_a
    sorted_results = @service.product_index(ActionController::Parameters.new(sort: "total_spend")).to_a

    assert_equal [ high_spend ], search_results
    assert_equal [ high_spend, low_spend ], sorted_results
  end

  test "dashboard snapshot exposes read model data for the purchasing dashboard" do
    product = create_product("Half and Half", needs_review: true)
    create_observation(
      product: product,
      line_total: 12,
      package_price: 12,
      standard_unit_price: nil,
      possible_price_spike: true,
      presentation_key: "quart"
    )

    snapshot = @service.dashboard_snapshot

    assert_equal BigDecimal("12"), snapshot.total_spend
    assert_equal 1, snapshot.receipt_count
    assert_equal 1, snapshot.product_count
    assert_equal [ [ "Dairy", BigDecimal("12") ] ], snapshot.category_spend
    assert_equal [ product ], snapshot.top_by_frequency.to_a
    assert_equal [ product ], snapshot.top_by_spend.to_a
    assert_equal [ product ], snapshot.missing_standard.to_a
    assert_equal [ product ], snapshot.needs_review.to_a
    assert_equal product, snapshot.spikes.first.product
  end

  test "report rows use the shared price stats and frequent-item ordering" do
    first_product = create_product("Oat Milk")
    second_product = create_product("Orange Juice")
    create_observation(product: first_product, line_total: 20, package_price: 20, presentation_key: "case")
    create_observation(product: second_product, line_total: 15, package_price: 15, presentation_key: "case")
    create_observation(product: first_product, line_total: 25, package_price: 25, presentation_key: "case")

    master_rows = @service.master_product_rows
    frequent_rows = @service.frequent_item_rows(limit: 2)
    oat_milk_row = master_rows.find { |row| row.second == "Oat Milk" }

    assert_equal 2, oat_milk_row[11]
    assert_equal BigDecimal("45"), oat_milk_row[13]
    assert_equal "Oat Milk", frequent_rows.first.first
    assert_equal 2, frequent_rows.first.third
  end

  private

  def create_product(name, needs_review: false)
    @supplier.products.create!(
      canonical_name: name,
      product_category: @category,
      needs_review: needs_review
    )
  end

  def create_observation(
    product:,
    observed_at: Time.zone.parse("2026-01-01 10:00:00"),
    package_price: 10,
    line_total: 10,
    quantity: 1,
    unit_quantity: quantity,
    case_quantity: 0,
    purchase_kind: "unit",
    inner_quantity: nil,
    inner_unit_price: nil,
    inner_unit_label: nil,
    standard_unit_price: nil,
    standard_unit: nil,
    standard_quantity: nil,
    presentation_key: "presentation",
    possible_price_spike: false
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
      unit_quantity: unit_quantity,
      case_quantity: case_quantity,
      inner_quantity: inner_quantity,
      inner_unit_price: inner_unit_price,
      inner_unit_label: inner_unit_label,
      package_price: package_price,
      line_total: line_total,
      parsed_package_size: standard_quantity,
      parsed_unit_of_measure: standard_unit,
      confidence_score: 1,
      needs_review: false,
      row_checksum: "row-#{@line_number}"
    )
    PriceObservation.create!(
      product: product,
      receipt_line_item: line_item,
      supplier: @supplier,
      observed_at: observed_at,
      package_price: package_price,
      unit_quantity: unit_quantity,
      case_quantity: case_quantity,
      purchase_kind: purchase_kind,
      inner_quantity: inner_quantity,
      inner_unit_price: inner_unit_price,
      inner_unit_label: inner_unit_label,
      quantity: quantity,
      line_total: line_total,
      standard_unit_price: standard_unit_price,
      standard_unit: standard_unit,
      standard_quantity: standard_quantity,
      presentation_key: presentation_key,
      presentation_label: presentation_key,
      source_filename: @import_batch.source_filename,
      possible_price_spike: possible_price_spike
    )
  end
end
