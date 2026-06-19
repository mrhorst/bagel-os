require "test_helper"

class SupplierProductPackTest < ActiveSupport::TestCase
  setup { @supplier = Supplier.primary }

  # ── Pure arithmetic (no persistence needed) ────────────────────────────────
  test "inner_quantity_for multiplies cases by units per case" do
    pack = SupplierProductPack.new(units_per_case: 6)

    assert_equal 12, pack.inner_quantity_for(case_quantity: 2)
    assert_nil pack.inner_quantity_for(case_quantity: nil)
  end

  test "inner_unit_price_for divides the line total across inner units" do
    pack = SupplierProductPack.new(units_per_case: 6)

    assert_equal 5, pack.inner_unit_price_for(line_total: 60, case_quantity: 2)
    assert_nil pack.inner_unit_price_for(line_total: 60, case_quantity: nil)
  end

  test "standard_quantity_for needs an inner package size and standard unit" do
    convertible = SupplierProductPack.new(units_per_case: 6, inner_package_size: 2, standard_unit: "oz")
    assert_equal 24, convertible.standard_quantity_for(case_quantity: 2)

    assert_nil SupplierProductPack.new(units_per_case: 6).standard_quantity_for(case_quantity: 2)
  end

  # ── Validations ─────────────────────────────────────────────────────────────
  test "requires a product, raw sku, or raw name so it can be matched" do
    pack = @supplier.supplier_product_packs.new(units_per_case: 6)

    assert_not pack.valid?
    assert pack.errors[:base].any? { |m| m.include?("matched safely") }
  end

  test "valid with just a raw name scope" do
    assert @supplier.supplier_product_packs.new(units_per_case: 6, raw_name: "Diced tomatoes").valid?
  end

  test "standard unit requires an inner package size" do
    pack = @supplier.supplier_product_packs.new(units_per_case: 6, raw_name: "Olive oil", standard_unit: "oz")

    assert_not pack.valid?
    assert_includes pack.errors[:inner_package_size], "is required when standard unit is present."
  end

  test "units_per_case must be positive" do
    assert_not @supplier.supplier_product_packs.new(units_per_case: 0, raw_name: "Salt").valid?
  end

  test "approved and case_packs scopes filter rows" do
    approved = @supplier.supplier_product_packs.create!(units_per_case: 6, raw_name: "Approved", approved: true)
    pending  = @supplier.supplier_product_packs.create!(units_per_case: 6, raw_name: "Pending")

    assert_includes SupplierProductPack.approved, approved
    assert_not_includes SupplierProductPack.approved, pending
    assert_includes SupplierProductPack.case_packs, pending
  end
end
