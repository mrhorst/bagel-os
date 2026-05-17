require "test_helper"

class ProductNormalizerTest < ActiveSupport::TestCase
  ParsedUnit = Struct.new(:package_size, :unit_of_measure, :standard_unit, keyword_init: true)

  setup do
    load Rails.root.join("db/seeds.rb")
    @supplier = Supplier.primary
    @batch = @supplier.import_batches.create!(
      source_filename: "product-normalizer-test.csv",
      source_path: "product-normalizer-test.csv",
      file_checksum: "product-normalizer-test",
      imported_at: Time.zone.local(2026, 5, 17),
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @batch,
      receipt_number: "PN-1",
      purchased_at: Time.zone.local(2026, 5, 17)
    )
  end

  test "groups family shorthand by canonical product and clears item-specific package fields" do
    first_line = create_line!(raw_name: "BACON THICK CUT", raw_sku: "BACON-THICK")
    second_line = create_line!(raw_name: "BACON SLICED", raw_sku: "BACON-SLICED", line_number: 2)
    parsed_unit = ParsedUnit.new(package_size: 5, unit_of_measure: "lb", standard_unit: "lb")

    product = normalizer.match_or_create!(first_line, parsed_unit)
    same_product = normalizer.match_or_create!(second_line, parsed_unit)

    assert_equal product, same_product
    assert_equal "Bacon", product.reload.canonical_name
    assert_nil product.supplier_sku
    assert_nil product.package_size
    assert_nil product.unit_of_measure
    assert_nil product.standard_unit
    assert_not product.needs_review?
    assert_equal [ "BACON SLICED", "BACON THICK CUT" ], product.product_aliases.order(:raw_name).pluck(:raw_name)
    assert_match(/Raw variations kept as aliases: BACON SLICED; BACON THICK CUT/, product.notes)
  end

  test "keeps non-family fallback products tied to the visible sku and parsed package" do
    line_item = create_line!(raw_name: "VERY SPECIFIC LOCAL ITEM 12OZ", raw_sku: "LOCAL-12")
    parsed_unit = ParsedUnit.new(package_size: 12, unit_of_measure: "oz", standard_unit: "oz")

    product = normalizer.match_or_create!(line_item, parsed_unit)

    assert_equal "Very Specific Local Item", product.canonical_name
    assert_equal "LOCAL-12", product.supplier_sku
    assert_equal BigDecimal("12"), product.package_size
    assert_equal "oz", product.unit_of_measure
    assert_equal "oz", product.standard_unit
    assert product.needs_review?
  end

  test "flags possible alias matches for fallback products without auto-merging" do
    category = ProductCategory.find_by!(name: "Other / unknown")
    possible_match = @supplier.products.create!(
      canonical_name: "Very Specific Local Item Extra",
      product_category: category,
      needs_review: false
    )
    line_item = create_line!(raw_name: "VERY SPECIFIC LOCAL ITEM EXTRA 12OZ", raw_sku: "LOCAL-EXTRA")
    parsed_unit = ParsedUnit.new(package_size: 12, unit_of_measure: "oz", standard_unit: "oz")

    product = normalizer.match_or_create!(line_item, parsed_unit)

    assert_not_equal possible_match, product
    review = line_item.normalization_reviews.find_by!(issue_type: "possible_alias_match")
    assert_equal possible_match, review.product
    assert_match(/not auto-merged/, review.description)
  end

  private

  def normalizer
    Purchasing::ProductNormalizer.new(supplier: @supplier)
  end

  def create_line!(raw_name:, raw_sku:, line_number: 1)
    @receipt.receipt_line_items.create!(
      supplier: @supplier,
      import_batch: @batch,
      line_number: line_number,
      line_type: "item",
      raw_name: raw_name,
      raw_sku: raw_sku,
      raw_quantity: "1",
      unit_quantity: 1,
      case_quantity: 0,
      quantity: 1,
      raw_unit: "unit",
      line_total: 10,
      package_price: 10,
      row_checksum: "product-normalizer-line-#{line_number}",
      needs_review: false
    )
  end
end
