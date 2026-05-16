require "test_helper"

class CasePackResolverTest < ActiveSupport::TestCase
  setup do
    @supplier = Supplier.create!(name: "Primary Supplier")
    @product = @supplier.products.create!(canonical_name: "American Cheese Yellow")
  end

  test "matches approved case pack facts by raw sku" do
    fact = @supplier.supplier_product_packs.create!(
      product: @product,
      raw_sku: "CHEESE-CASE",
      units_per_case: 4,
      inner_unit_label: "pack",
      approved: true,
      confidence_score: 1
    )

    resolved = Purchasing::CasePackResolver.new.resolve(
      line_data: {
        supplier: @supplier,
        raw_sku: "CHEESE-CASE",
        raw_name: "CHS AMER YLW",
        raw_quantity: "0",
        raw_case_quantity: "1"
      },
      product: @product
    )

    assert_equal fact, resolved
  end

  test "does not use unapproved facts or unit purchases" do
    @supplier.supplier_product_packs.create!(
      product: @product,
      raw_sku: "CHEESE-CASE",
      units_per_case: 4,
      inner_unit_label: "pack",
      approved: false,
      confidence_score: 1
    )

    resolver = Purchasing::CasePackResolver.new

    assert_nil resolver.resolve(
      line_data: { supplier: @supplier, raw_sku: "CHEESE-CASE", raw_quantity: "0", raw_case_quantity: "1" },
      product: @product
    )
    assert_nil resolver.resolve(
      line_data: { supplier: @supplier, raw_sku: "CHEESE-CASE", raw_quantity: "1", raw_case_quantity: "0" },
      product: @product
    )
  end
end
