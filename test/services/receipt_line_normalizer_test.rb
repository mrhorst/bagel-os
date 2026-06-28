require "test_helper"

class ReceiptLineNormalizerTest < ActiveSupport::TestCase
  test "normalizes clear receipt units into line attributes and trace payload" do
    result = normalize(
      raw_name: "EGGS XLG LS GRD A 15DZ",
      raw_quantity: "1",
      line_total: BigDecimal("30.00")
    )

    attributes = result.line_item_attributes
    assert_not result.needs_review?
    assert_empty result.review_intents
    assert_equal BigDecimal("15"), attributes[:parsed_package_size]
    assert_equal "dozen", attributes[:parsed_unit_of_measure]
    assert_equal BigDecimal("1"), attributes[:unit_quantity]
    assert_equal BigDecimal("0"), attributes[:case_quantity]
    assert_equal BigDecimal("1"), attributes[:quantity]
    assert_equal "unit", attributes[:raw_data]["calculated"]["purchase_kind"]
    assert_equal BigDecimal("30.0"), attributes[:package_price]
    assert_equal BigDecimal("15"), attributes[:raw_data]["calculated"]["standard_quantity"]
    assert_equal BigDecimal("2.0"), attributes[:raw_data]["calculated"]["standard_unit_price"]
    assert_equal "EGGS XLG LS GRD A 15DZ", attributes[:raw_data]["row"][1]
  end

  test "flags ambiguous multipack rows without inventing comparable units" do
    result = normalize(
      raw_name: "PD MUSH SLICED WHT 6-20OZ",
      raw_quantity: "1",
      line_total: BigDecimal("10.00")
    )

    assert result.needs_review?
    assert_nil result.calculated[:standard_unit_price]
    assert_nil result.line_item_attributes[:parsed_package_size]
    assert_includes result.review_intents.map(&:issue_type), "unit_parse"
    assert_match(/multi-pack/, result.review_intents.first.description)
  end

  test "flags case pack rows when visible package size may be an inner pack" do
    result = normalize(
      raw_name: "BTR SWT QRTS ST 1LB",
      raw_quantity: "0",
      raw_case_quantity: "1",
      line_total: BigDecimal("45.00")
    )

    assert result.needs_review?
    assert_equal BigDecimal("1"), result.line_item_attributes[:parsed_package_size]
    assert_equal BigDecimal("0"), result.line_item_attributes[:unit_quantity]
    assert_equal BigDecimal("1"), result.line_item_attributes[:case_quantity]
    assert_equal "case", result.calculated[:purchase_kind]
    assert_nil result.calculated[:standard_unit_price]
    assert_includes result.review_intents.map(&:issue_type), "unit_parse"
    assert_includes result.review_intents.map(&:issue_type), "case_pack"
  end

  test "does not calculate comparable unit price for five pound case rows without a case pack fact" do
    result = normalize(
      raw_name: "CHS AM YL 160SL JF 5LB",
      raw_quantity: "0",
      raw_case_quantity: "1",
      line_total: BigDecimal("47.78")
    )

    assert result.needs_review?
    assert_equal BigDecimal("5"), result.line_item_attributes[:parsed_package_size]
    assert_equal BigDecimal("47.78"), result.line_item_attributes[:package_price]
    assert_nil result.calculated[:standard_quantity]
    assert_nil result.calculated[:standard_unit_price]
    assert_includes result.review_intents.map(&:issue_type), "case_pack"
  end

  test "keeps coupon rows traceable and reviewable" do
    result = normalize(
      line_type: "coupon",
      raw_name: "MANUFACTURER COUPON",
      raw_quantity: "1",
      line_total: BigDecimal("-5.00")
    )

    assert result.needs_review?
    assert_equal BigDecimal("-5.00"), result.line_item_attributes[:line_total]
    assert_includes result.review_intents.map(&:issue_type), "coupon"
  end

  test "keeps random weight rows on presentation pricing without standardizing" do
    result = normalize(
      raw_name: "BEEF R/W",
      raw_quantity: "1.25",
      line_total: BigDecimal("25.00")
    )

    assert result.needs_review?
    assert_equal "raw_quantity", result.line_item_attributes[:parsed_unit_of_measure]
    assert_equal BigDecimal("20.0"), result.calculated[:package_price]
    assert_nil result.calculated[:standard_unit_price]
    assert_includes result.review_intents.map(&:issue_type), "unit_parse"
  end

  test "uses product category context when deciding review state" do
    category = ProductCategory.new(name: "Other / unknown")
    product = Product.new(product_category: category)
    result = normalize(
      raw_name: "BANANAS 25LB",
      raw_quantity: "1",
      line_total: BigDecimal("25.00"),
      product: product
    )

    assert result.needs_review?
    assert_includes result.review_intents.map(&:issue_type), "missing_category"
  end

  test "tracks mixed unit and case quantities without allocating one package price" do
    result = normalize(
      raw_name: "BANANAS 25LB",
      raw_quantity: "1",
      raw_case_quantity: "1",
      line_total: BigDecimal("50.00")
    )

    attributes = result.line_item_attributes
    assert result.needs_review?
    assert_equal BigDecimal("1"), attributes[:unit_quantity]
    assert_equal BigDecimal("1"), attributes[:case_quantity]
    assert_nil attributes[:quantity]
    assert_nil attributes[:package_price]
    assert_equal "mixed", result.calculated[:purchase_kind]
    assert_includes result.review_intents.map(&:issue_type), "mixed_quantity"
  end

  test "uses approved case pack facts without keeping case pack rows in review" do
    supplier = Supplier.create!(name: "Primary Supplier")
    category = ProductCategory.create!(name: "Dairy")
    product = supplier.products.create!(canonical_name: "American Cheese Yellow", product_category: category)
    case_pack = supplier.supplier_product_packs.create!(
      product: product,
      raw_sku: "SKU123",
      raw_name: "CHS AMER YLW 5LB",
      units_per_case: 4,
      inner_unit_label: "pack",
      inner_package_size: 5,
      inner_unit_of_measure: "lb",
      standard_unit: "lb",
      source: "manual",
      approved: true,
      confidence_score: 1
    )

    result = normalize(
      raw_name: "CHS AMER YLW 5LB",
      raw_quantity: "0",
      raw_case_quantity: "1",
      line_total: BigDecimal("80.00"),
      product: product,
      supplier: supplier
    )

    assert_not result.needs_review?
    assert_empty result.review_intents
    assert_equal case_pack, result.line_item_attributes[:case_pack]
    assert_equal BigDecimal("4"), result.line_item_attributes[:inner_quantity]
    assert_equal BigDecimal("20.0"), result.line_item_attributes[:inner_unit_price]
    assert_equal BigDecimal("20"), result.calculated[:standard_quantity]
    assert_equal BigDecimal("4.0"), result.calculated[:standard_unit_price]
  end

  test "a clean-parse item line with no derivable price emits a resolvable price intent" do
    # A $0.00 / comp line parses cleanly but has no comparable price, so it is
    # flagged for review. Without a matching intent the flag would be stuck with
    # nothing to resolve on the edit page (#172).
    result = normalize(
      raw_name: "EGGS XLG LS GRD A 15DZ",
      raw_quantity: "1",
      line_total: BigDecimal("0")
    )

    assert result.needs_review?
    assert_nil result.calculated[:standard_unit_price]
    assert_nil result.calculated[:inner_unit_price]
    assert_includes result.review_intents.map(&:issue_type), "price"
  end

  test "a non-item, non-coupon row emits a resolvable adjustment intent" do
    result = normalize(
      line_type: "adjustment",
      raw_name: "FUEL SURCHARGE",
      raw_quantity: "0",
      line_total: BigDecimal("5.00")
    )

    assert result.needs_review?
    assert_includes result.review_intents.map(&:issue_type), "adjustment"
  end

  test "every line flagged for review emits at least one resolvable intent" do
    # The rest of the app assumes the invariant needs_review ⟺ a pending review
    # exists; a flagged line with zero intents becomes an unresolvable dead-end.
    cases = [
      { raw_name: "EGGS XLG LS GRD A 15DZ", raw_quantity: "1", line_total: BigDecimal("0") },           # price only
      { line_type: "adjustment", raw_name: "FUEL SURCHARGE", raw_quantity: "0", line_total: BigDecimal("5.00") }, # adjustment
      { line_type: "coupon", raw_name: "$2 OFF", raw_quantity: "1", line_total: BigDecimal("-2.00") },   # coupon
      { raw_name: "PD MUSH SLICED WHT 6-20OZ", raw_quantity: "1", line_total: BigDecimal("10.00") }      # unit parse
    ]

    cases.each do |attrs|
      result = normalize(**attrs)
      next unless result.needs_review?

      assert result.review_intents.any?,
        "#{attrs[:raw_name]} is flagged for review but emits no resolvable intent"
    end
  end

  private

  def normalize(line_type: "item", raw_name:, raw_quantity:, line_total:, raw_case_quantity: "0", product: nil, supplier: nil)
    line_data = {
      line_number: 12,
      line_type: line_type,
      supplier: supplier,
      raw_sku: "SKU123",
      raw_name: raw_name,
      raw_quantity: raw_quantity,
      raw_case_quantity: raw_case_quantity,
      line_total: line_total,
      raw_data: {
        source_filename: "sample.csv",
        csv_line_number: 12,
        row: [ "SKU123", raw_name, raw_quantity, raw_case_quantity, line_total.to_s("F") ]
      }
    }

    Purchasing::ReceiptLineNormalizer.new.normalize(line_data: line_data, product: product)
  end
end
